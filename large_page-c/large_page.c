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
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <inttypes.h>
#include <linux/limits.h>
#include <regex.h>

extern char __attribute__((weak))  __textsegment;

typedef struct {
  void*     from;
  void*     to;
} mem_range;

#define HPS (2L * 1024 * 1024)
#define SAFE_DEL(p, func) {if (p) { func(p); p = NULL; }}

static inline uintptr_t largepage_align_down(uintptr_t addr) {
  return (addr & ~(HPS - 1));
}

static inline uintptr_t largepage_align_up(uintptr_t addr) {
  return largepage_align_down(addr + HPS - 1);
}

// Identify and return the text region in the currently mapped memory regions.
static map_status FindTextRegion(const char* lib_regex, mem_range* region) {
  FILE* ifs = NULL;
  char* map_line = NULL;
  size_t line_buff_size = 0;
  char permission[5] = {0};                 // xxxx
  char dev[8] = {0};                        // xxx:xxx
  char exename[PATH_MAX] = {0};             // One path
  char pathname[PATH_MAX] = {0};            // One path
  bool result;
  regex_t regex = {0};
  ssize_t total_read;
  uintptr_t start, end;
  int64_t offset, inode;
  int matched;

#define CLEAN_EXIT(retcode)         \
  SAFE_DEL(ifs, fclose);            \
  SAFE_DEL(map_line, free);         \
  regfree(&regex);                  \
  return retcode;

  ifs = fopen("/proc/self/maps", "rt");
  if (!ifs) {
    CLEAN_EXIT(map_maps_open_failed);
  }

  result = (lib_regex != NULL) ||
           (readlink("/proc/self/exe", exename, PATH_MAX) > 0);
  if (!result) {
    CLEAN_EXIT(map_exe_path_read_failed);
  }

  result = (lib_regex == NULL) ||
           (regcomp(&regex, lib_regex, 0) == 0);
  if (!result) {
    CLEAN_EXIT(map_invalid_regex);
  }

  // The following is the format of the maps file
  // address           perms offset  dev   inode       pathname
  // 00400000-00452000 r-xp 00000000 08:02 173521      /usr/bin/dbus-daemon
  while ((total_read = getline(&map_line, &line_buff_size, ifs)) > 0) {
    if (total_read < 16) {
      continue;
    }
    matched = sscanf(map_line, " %lx-%lx %s %lx %s %lx %s ",
                     &start, &end, permission,
                     &offset, dev, &inode, pathname);
    if (matched < 6) {
      CLEAN_EXIT(map_malformed_maps_file);
    }
    if (inode != 0 && strcmp(permission, "r-xp") == 0) {
      if (lib_regex == NULL) {
        result = (strcmp(pathname, exename) == 0 &&
                  start <= (uintptr_t)(&__textsegment) &&
                  end >= (uintptr_t)(&__textsegment));
        start = (uintptr_t)(&__textsegment);
      } else {
        result = (regexec(&regex, pathname, 0, NULL, 0) == 0);
      }
      if (result) {
        region->from = (void*)start;
        region->to = (void*)end;
        CLEAN_EXIT(map_ok);
      }
    }
  }
  CLEAN_EXIT(map_region_not_found);

#undef CLEAN_EXIT
}

static map_status IsTransparentHugePagesEnabled(bool* result) {
  FILE* ifs;
  char always[16] = {0};
  char madvise[16] = {0};
  char never[16] = {0};
  int matched;

  *result = false;
  ifs = fopen("/sys/kernel/mm/transparent_hugepage/enabled", "rt");
  if (!ifs) {
    return map_failed_to_open_thp_file;
  }

  matched = fscanf(ifs, "%s %s %s", always, madvise, never);
  fclose(ifs);

  if (matched != 3) {
    return map_malformed_thp_file;
  }

  if (strcmp(always, "[always]") == 0) {
    *result = true;
  } else if (strcmp(madvise, "[madvise]") == 0) {
    *result = true;
  } else if (strcmp(never, "[never]") == 0) {
    *result = false;
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
static map_status
__attribute__((__section__(".lpstub")))
__attribute__((__aligned__(HPS)))
__attribute__((__noinline__))
MoveRegionToLargePages(const mem_range* r) {
  void* nmem = NULL;
  void* tmem = NULL;
  int ret = 0;
  map_status status = map_ok;
  void* start = r->from;
  size_t size = r->to - r->from;

  // Allocate temporary region preparing for copy
  nmem = mmap(NULL, size,
              PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (nmem == MAP_FAILED) {
    return map_see_errno;
  }

  memcpy(nmem, r->from, size);

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
static void AlignRegionToPageBoundary(mem_range* r) {
  r->from = (void*)(largepage_align_up((uintptr_t)r->from));
  r->to = (void*)(largepage_align_down((uintptr_t)r->to));
}

static map_status CheckMemRange(mem_range* r) {
  if (r->from == NULL || r->to == NULL || r->from > r->to) {
    return map_invalid_region_address;
  }

  if (r->to - r->from < HPS) {
    return map_region_too_small;
  }

  return map_ok;
}

// Align the region to to be mapped to 2MB page boundaries and then move the
// region to large pages.
static map_status AlignMoveRegionToLargePages(mem_range* r) {
  map_status status;
  AlignRegionToPageBoundary(r);

  status = CheckMemRange(r);
  if (status != map_ok) {
    return status;
  }

  if (r->from > (void*)MoveRegionToLargePages ||
      r->to <= (void*)MoveRegionToLargePages) {
    return MoveRegionToLargePages(r);
  }

  return map_mover_overlaps;
}

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
map_status MapStaticCodeToLargePages() {
  mem_range r = {0};
  map_status status = FindTextRegion(NULL, &r);
  if (status != map_ok) {
    return status;
  }
  return AlignMoveRegionToLargePages(&r);
}

map_status MapDSOToLargePages(const char* lib_regex) {
  mem_range r = {0};
  map_status status;

  if (lib_regex == NULL) {
    return map_null_regex;
  }

  status = FindTextRegion(lib_regex, &r);
  if (status != map_ok) {
    return status;
  }
  return AlignMoveRegionToLargePages(&r);
}

// This function is similar to the function above. However, the region to be
// mapped to 2MB pages is specified for this version as hotStart and hotEnd.
map_status MapStaticCodeRangeToLargePages(void* from, void* to) {
  mem_range r = {from, to};
  return AlignMoveRegionToLargePages(&r);
}

// Return true if transparent huge pages is enabled on the system. Otherwise,
// return false.
map_status IsLargePagesEnabled(bool* result) {
  return IsTransparentHugePagesEnabled(result);
}

const char* MapStatusStr(map_status status, bool fulltext) {
  static const char* map_status_text[] = {
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
  return map_status_text[((int)status << 1) + (fulltext & 1)];
}
