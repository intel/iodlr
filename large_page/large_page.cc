// Copyright (C) 2018 Intel Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom
// the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
// OR OTHER DEALINGS IN THE SOFTWARE.
//
// SPDX-License-Identifier: MIT

#include "large_page.h"

#include <sys/mman.h>
#include <unistd.h>
#include <climits>
#include <cstring>
#include <iostream>
#include <fstream>
#include <sstream>
#include <regex>
#include <inttypes.h>

extern char __attribute__((weak))  __textsegment;

namespace largepage {

  using std::pair;
  using std::string;
  using std::ifstream;
  using std::istringstream;
  using std::cout;
  using std::cerr;
  using std::regex;
  using std::smatch;


namespace {

struct MemRange {
  void*     from;
  void*     to;
  MemRange() : from(nullptr), to(nullptr) {}
  MemRange(void* from, void* to) : from(from), to(to) {}
  void set(void* f, void* t) { from = f; to = t; }
};

constexpr size_t hps = 2L * 1024 * 1024;

constexpr uintptr_t LargePageAlignDown(uintptr_t addr) {
  return (addr & ~(hps - 1));
}

constexpr uintptr_t LargePageAlignUp(uintptr_t addr) {
  return LargePageAlignDown(addr + hps - 1);
}

// Identify and return the text region in the currently mapped memory regions.
MapStatus FindTextRegion(MemRange* region, const string& regexpr = "") {
  string exename;
  string map_line;
  regex lib_regex(regexpr);
  bool result;
  char selfexe[PATH_MAX] = {0};

  ifstream ifs("/proc/self/maps");

  if (!ifs) {
    return map_maps_open_failed;
  }

  ssize_t count = readlink("/proc/self/exe", selfexe, PATH_MAX);
  if (count < 0) {
    return map_exe_path_read_failed;
  }
  exename.assign(selfexe, count);

// The following is the format of the maps file
// address           perms offset  dev   inode       pathname
// 00400000-00452000 r-xp 00000000 08:02 173521      /usr/bin/dbus-daemon
  while (getline(ifs, map_line)) {
    string permission;
    string dev;
    char dash;
    uint64_t offset, inode;
    uintptr_t start, end;

    istringstream iss(map_line);
    iss >> std::hex >> start;
    iss >> dash;
    iss >> std::hex >> end;
    iss >> permission;
    iss >> offset;
    iss >> dev;
    iss >> inode;

    if (inode != 0 && permission == "r-xp") {
      string pathname;
      iss >> pathname;
      if (regexpr.size() == 0) {
        result = (pathname == exename &&
                  start <= (uintptr_t)(&__textsegment) &&
                  end >= (uintptr_t)(&__textsegment));
        start = (uintptr_t)(&__textsegment);
      } else {
        smatch lib_match;
        result = regex_search(pathname, lib_match, lib_regex);
      }
      if (result) {
        region->set(reinterpret_cast<void*>(start),
                    reinterpret_cast<void*>(end));
        return map_ok;
      }
    }
  }
  return map_region_not_found;
}

MapStatus IsTransparentHugePagesEnabled(bool* result) {
  *result = false;
  ifstream ifs("/sys/kernel/mm/transparent_hugepage/enabled");
  if (!ifs) {
    return map_failed_to_open_thp_file;
  }

  string always;
  string madvise;
  string never;

  pair<string*, bool> check_items[] = {{ &always, true },
                                       { &madvise, true },
                                       { &never, false }};

  ifs >> always >> madvise >> never;

  for (auto check : check_items) {
    if (check.first->size() == 0) {
      return map_malformed_thp_file;
    }

    if (*(check.first->begin()) == '[' && *(check.first->rbegin()) == ']') {
      *result = check.second;
      break;
    }
  }
  return map_ok;
}

// Move specified region to large pages. We need to be very careful.
// 1: This function itself should not be moved.
// We use a gcc attributes
// (__section__) to put it outside the ".text" section
// (__aligned__) to align it at 2M boundary
// (__noline__) to not inline this function
// 2: This function should not call any function(s) that might be moved.
// a. map a new area and copy the original code there
// b. mmap using the start address with MAP_FIXED so we get exactly
//    the same virtual address
// c. madvise with MADV_HUGE_PAGE
// d. If successful copy the code there and unmap the original region
MapStatus
__attribute__((__section__(".lpstub")))
__attribute__((__aligned__(hps)))
__attribute__((__noinline__))
MoveRegionToLargePages(const MemRange& r) {
  void* nmem = nullptr;
  void* tmem = nullptr;
  int ret = 0;
  MapStatus status = map_ok;
  void* start = r.from;
  size_t size = reinterpret_cast<size_t>(r.to) -
                reinterpret_cast<size_t>(r.from);

// Allocate temporary region preparing for copy
  nmem = mmap(nullptr, size,
              PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (nmem == MAP_FAILED) {
    return map_see_errno;
  }

  memcpy(nmem, r.from, size);

// We already know the original page is r-xp
// (PROT_READ, PROT_EXEC, MAP_PRIVATE)
// We want PROT_WRITE because we are writing into it.
// We want it at the fixed address and we use MAP_FIXED.
#define CLEAN_EXIT_CHECK(oper)                          \
  if (tmem == MAP_FAILED) {                             \
    status = oper##_failed;                             \
    ret = munmap(nmem, size);                           \
    if (ret < 0) {                                      \
      status = oper##_munmap_nmem_failed;               \
    }                                                   \
    return status;                                      \
  }

  tmem = mmap(start, size,
              PROT_READ | PROT_WRITE | PROT_EXEC,
              MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1 , 0);
CLEAN_EXIT_CHECK(map_see_errno_mmap_tmem);

#undef CLEAN_EXIT_CHECK

#define CLEAN_EXIT_CHECK(oper)                          \
  if (ret < 0) {                                        \
    status = oper##_failed;                             \
    ret = munmap(tmem, size);                           \
    if (ret < 0) {                                      \
      status = oper##_munmap_tmem_failed;               \
    }                                                   \
    ret = munmap(nmem, size);                           \
    if (ret < 0) {                                      \
      status = (status == oper##_munmap_tmem_failed)    \
        ? oper##_munmaps_failed                         \
        : oper##_munmap_nmem_failed;                    \
    }                                                   \
    return status;                                      \
  }

  ret = madvise(tmem, size, MADV_HUGEPAGE);
  CLEAN_EXIT_CHECK(map_see_errno_madvise_tmem);

  memcpy(start, nmem, size);
  ret = mprotect(start, size, PROT_READ | PROT_EXEC);
  CLEAN_EXIT_CHECK(map_see_errno_mprotect);

#undef CLEAN_EXIT_CHECK

  // Release the old/temporary mapped region
  ret = munmap(nmem, size);
  if (ret < 0) {
    status = map_see_errno_munmap_nmem_failed;
  }

  return status;
}

// Align the region to to be mapped to 2MB page boundaries.
void AlignRegionToPageBoundary(MemRange* r) {
  r->from = reinterpret_cast<void*>(LargePageAlignUp(
                      reinterpret_cast<uintptr_t>(r->from)));
  r->to = reinterpret_cast<void*>(LargePageAlignDown(
                      reinterpret_cast<uintptr_t>(r->to)));
}

MapStatus CheckMemRange(const MemRange& r) {
  if (r.from == nullptr || r.to == nullptr || r.from > r.to) {
    return map_invalid_region_address;
  }

  if (reinterpret_cast<size_t>(r.to) -
      reinterpret_cast<size_t>(r.from) < hps) {
    return map_region_too_small;
  }

  return map_ok;
}

// Align the region to to be mapped to 2MB page boundaries and then move the
// region to large pages.
MapStatus AlignMoveRegionToLargePages(MemRange r) {
  AlignRegionToPageBoundary(&r);

  MapStatus status = CheckMemRange(r);
  if (status != map_ok) {
    return status;
  }

  if (r.from > (void*)MoveRegionToLargePages ||
      r.to <= (void*)MoveRegionToLargePages) {
    return MoveRegionToLargePages(r);
  }

  return map_mover_overlaps;
}

}  // namespace

// Map the .text segment of the linked application into 2MB pages.
// The algorithm is simple:
// 1. Find the text region of the executing binary in memory
//    * Examine the /proc/self/maps to determine the currently mapped text
//      region and obtain the start and end addresses.
//    * Modify the start address to point to the very beginning of .text segment
//      (from variable textsegment setup in ld.script).
//    * Align the address of start and end addresses to large page boundaries.
//
// 2: Move the text region to large pages
//    * Map a new area and copy the original code there.
//    * Use mmap using the start address with MAP_FIXED so we get exactly the
//      same virtual address.
//    * Use madvise with MADV_HUGE_PAGE to use anonymous 2M pages.
//    * If successful, copy the code to the newly mapped area and unmap the
//      original region.
MapStatus MapStaticCodeToLargePages(const std::string& regexpr) {
  MemRange r;
  MapStatus status = FindTextRegion(&r, regexpr);
  if (status != map_ok) {
    return status;
  }
  return AlignMoveRegionToLargePages(r);
}

// This function is similar to the function above. However, the region to be
// mapped to 2MB pages is specified for this version as hotStart and hotEnd.
MapStatus MapStaticCodeToLargePages(void* from, void* to) {
  return AlignMoveRegionToLargePages(MemRange(from, to));
}

MapStatus IsLargePagesEnabled(bool* result) {
  return IsTransparentHugePagesEnabled(result);
}

const string& MapStatusStr(MapStatus status, bool fulltext) {
  static string map_status_text[] = {
    "map_ok",
      "ok",
    "map_exe_path_read_failed",
      "failed to read executable path file",
    "map_failed_to_open_thp_file",
      "failed to open thp enablement status file",
    "map_invalid_regex",
      "invalid regex",
    "map_invalid_region_address",
      "invalid region boundaries",
    "map_malformed_thp_file",
      "malformed thp enablement status file",
    "map_malformed_maps_file",
      "malformed /proc/<PID>/maps file",
    "map_maps_open_failed",
      "failed to open maps file",
    "map_mover_overlaps",
      "the remapping function is part of the region",
    "map_null_regex",
      "regex was NULL",
    "map_region_not_found",
      "map region not found",
    "map_region_too_small",
      "map region too small",
    "map_see_errno",
      "see errno",
    "map_see_errno_madvise_tmem_failed",
      "madvise for destination failed",
    "map_see_errno_madvise_tmem_munmap_nmem_failed",
      "madvise for destination and unmapping of temporary failed",
    "map_see_errno_madvise_tmem_munmaps_failed",
      "madvise for destination and unmappings failed",
    "map_see_errno_madvise_tmem_munmap_tmem_failed",
      "madvise for destination and unmapping of destination failed",
    "map_see_errno_mmap_tmem_failed",
      "mapping of destination failed",
    "map_see_errno_mmap_tmem_munmap_nmem_failed",
      "mapping of destination and unmapping of temporary failed",
    "map_see_errno_mprotect_failed",
      "mprotect failed",
    "map_see_errno_mprotect_munmap_nmem_failed",
      "mprotect and unmapping of temporary failed",
    "map_see_errno_mprotect_munmaps_failed",
      "mprotect and unmappings failed",
    "map_see_errno_mprotect_munmap_tmem_failed",
      "mprotect and unmapping of destination failed",
    "map_see_errno_munmap_nmem_failed",
      "unmapping of temporary failed"
  };
  return map_status_text[(static_cast<int>(status) << 1) + (fulltext & 1)];
}

}  // namespace largepage
