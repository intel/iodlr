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

#ifndef LARGE_PAGE_H_
#define LARGE_PAGE_H_

#include <stdbool.h>

typedef enum {
  map_ok,
  map_exe_path_read_failed,
  map_failed_to_open_thp_file,
  map_invalid_regex,
  map_invalid_region_address,
  map_malformed_thp_file,
  map_malformed_maps_file,
  map_maps_open_failed,
  map_null_regex,
  map_region_not_found,
  map_region_too_small,
  map_see_errno,
  map_see_errno_madvise_tmem_failed,
  map_see_errno_madvise_tmem_munmap_nmem_failed,
  map_see_errno_madvise_tmem_munmaps_failed,
  map_see_errno_madvise_tmem_munmap_tmem_failed,
  map_see_errno_mmap_tmem_failed,
  map_see_errno_mmap_tmem_munmap_nmem_failed,
  map_see_errno_mprotect_failed,
  map_see_errno_mprotect_munmap_nmem_failed,
  map_see_errno_mprotect_munmaps_failed,
  map_see_errno_mprotect_munmap_tmem_failed,
  map_see_errno_munmap_nmem_failed,
  map_unsupported_platform,
} map_status;

#define MAP_STATUS_STR(status)        MapStatusStr(status, true)
#define MAP_STATUS_STR_SHORT(status)  MapStatusStr(status, false)

map_status MapStaticCodeToLargePages();
map_status MapDSOToLargePages(const char* lib_regex);
map_status MapStaticCodeRangeToLargePages(void* from, void* to);
map_status IsLargePagesEnabled(bool* result);
const char* MapStatusStr(map_status status, bool fulltext);

#endif  // LARGE_PAGE_H_
