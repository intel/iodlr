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

typedef struct _text_region {
  void*     from;
  void*     to;
  size_t    total_largepages;
  bool      found_text_region;
} text_region;

#define HPS (2L * 1024 * 1024)

static const size_t hps = HPS;

static inline uint64_t largepage_align_up(uint64_t addr) {
  return (((addr) + (hps) - 1) & ~((hps) - 1));
}

static inline uintptr_t largepage_align_down(uintptr_t addr) {
  return ((addr) & ~((hps) - 1));
}

// Identify and return the text region in the currently mapped memory regions.
static map_status FindTextRegion(const char* lib_regex, text_region* region) {
  FILE* ifs = NULL;
  size_t line_buff_size = PATH_MAX + 256; // One path + extra data
  char* map_line = (char*)malloc(line_buff_size);

  char permission[5] = {0};         // xxxx
  char dev[8];                      // xxx:xxx
  char exename[PATH_MAX];           // One path
  char pathname[PATH_MAX];          // One path
  ssize_t total_read;
  bool result;
  regex_t regex;
  int64_t start, end, offset, inode;

  region->found_text_region = false;

#define CLEANUP()                   \
  if (ifs) { fclose(ifs); }         \
  if (map_line) { free(map_line); } \
  regfree(&regex);

  ifs = fopen("/proc/self/maps", "rt");
  if (!ifs) {
    free(map_line);
    return map_maps_open_failed;
  }

  result = (lib_regex != NULL) ||
           (readlink("/proc/self/exe", exename, PATH_MAX) > 0);
  if (!result) {
    CLEANUP();
    return map_exe_path_read_failed;
  }

  result = (lib_regex == NULL) ||
           (regcomp(&regex, lib_regex, 0) == 0);
  if (!result) {
    CLEANUP();
    return map_invalid_regex;
  }

  // The following is the format of the maps file
  // address           perms offset  dev   inode       pathname
  // 00400000-00452000 r-xp 00000000 08:02 173521      /usr/bin/dbus-daemon
  while ((total_read = getline(&map_line, &line_buff_size, ifs)) > 0) {
    if (total_read < 16) {
      continue;
    }
    sscanf(map_line, " %lx-%lx %s %lx %s %lx %s ",
           &start, &end, permission, &offset, dev, &inode, pathname);
    if (inode != 0 && strcmp(permission, "r-xp") == 0) {
      if (lib_regex == NULL) {
        result = (strcmp(pathname, exename) == 0 &&
                  start <= (int64_t)(&__textsegment) &&
                  end >= (int64_t)(&__textsegment));
      } else {
        result = (regexec(&regex, pathname, 0, NULL, 0) == 0);
      }
      if (result) {
        region->found_text_region = true;
        region->from = (void*)start;
        region->to = (void*)end;
        break;
      }
    }
  }
  CLEANUP();
  return region->found_text_region ? map_ok : map_region_not_found;
}

static map_status IsTransparentHugePagesEnabled(bool* result) {
  FILE* ifs;

  *result = false;
  ifs = fopen("/sys/kernel/mm/transparent_hugepage/enabled", "rt");
  if (!ifs) {
    return map_failed_to_open_thp_file;
  }

  char always[16] = {0};
  char madvise[16] = {0};
  char never[16] = {0};
  int matched = fscanf(ifs, "%s %s %s", always, madvise, never);
  fclose (ifs);

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
MoveRegionToLargePages(const text_region* r) {
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
  tmem = mmap(start, size,
              PROT_READ | PROT_WRITE | PROT_EXEC,
              MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED, -1 , 0);
  if (tmem == MAP_FAILED) {
    status = map_see_errno_mmap_tmem_failed;
    ret = munmap(nmem, size);
    if (ret < 0) {
      status = map_see_errno_mmap_tmem_munmap_nmem_failed;
    }
    return status;
  }

  ret = madvise(tmem, size, MADV_HUGEPAGE);
  if (ret < 0) {
    status = map_see_errno_madvise_tmem_failed;
    ret = munmap(tmem, size);
    if (ret < 0) {
      status = map_see_errno_madvise_tmem_munmap_tmem_failed;
    }
    ret = munmap(nmem, size);
    if (ret < 0) {
      status = (status == map_see_errno_madvise_tmem_munmap_tmem_failed)
        ? map_see_errno_madvise_tmem_munmaps_failed
        : map_see_errno_madvise_tmem_munmap_nmem_failed;
    }

    return status;
  }

  memcpy(start, nmem, size);
  ret = mprotect(start, size, PROT_READ | PROT_EXEC);
  if (ret < 0) {
    status = map_see_errno_mprotect_failed;
    ret = munmap(tmem, size);
    if (ret < 0) {
      status = map_see_errno_mprotect_munmap_tmem_failed;
    }
    ret = munmap(nmem, size);
    if (ret < 0) {
      status = (status == map_see_errno_mprotect_munmap_tmem_failed)
        ? map_see_errno_mprotect_munmaps_failed
        : map_see_errno_mprotect_munmap_tmem_failed;
    }
    return status;
  }

  // Release the old/temporary mapped region
  ret = munmap(nmem, size);
  if (ret < 0) {
    status = map_see_errno_munmap_nmem_failed;
  }

  return status;
}

// Align the region to to be mapped to 2MB page boundaries.
static void AlignRegionToPageBoundary(text_region* r) {
  r->from = (void*)(largepage_align_up((int64_t)r->from));
  r->to = (void*)(largepage_align_down((int64_t)r->to));
  r->total_largepages = (r->to - r->from) / hps;
}

static map_status IsRegionValid(text_region* r) {
  if (r->found_text_region == false) {
    return map_region_not_found;
  }

  if (r->from == NULL || r->to == NULL || r->from > r->to) {
    return map_invalid_region_address;
  }

  if (r->total_largepages < 1) {
    return map_region_too_small;
  }

  return map_ok;
}

// Align the region to to be mapped to 2MB page boundaries and then move the
// region to large pages.
static map_status AlignMoveRegionToLargePages(text_region* r) {
  map_status status;
  AlignRegionToPageBoundary(r);

  status = IsRegionValid(r);
  if (status != map_ok) {
    return status;
  }

  if (r->from > (void*)MoveRegionToLargePages ||
      r->to <= (void*)MoveRegionToLargePages) {
    return MoveRegionToLargePages(r) == -1 ? map_see_errno : map_ok;
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
  text_region r;
  map_status status = FindTextRegion(NULL, &r);
  if (status != map_ok) {
    return status;
  }
  return AlignMoveRegionToLargePages(&r);
}

map_status MapDSOToLargePages(const char* lib_regex) {
  map_status status;
  text_region r;

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
  text_region r = {from, to, true, 0};
  return AlignMoveRegionToLargePages(&r);
}

// Return true if transparent huge pages is enabled on the system. Otherwise,
// return false.
map_status IsLargePagesEnabled(bool* result) {
  return IsTransparentHugePagesEnabled(result);
}
