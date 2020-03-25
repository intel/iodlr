# Reference Implementation for Utilizing Large Pages

This directory contains a reference implementation for automating the process
of utilizing transparent huge pages.

## Building

The APIs provided by the reference implementation can be built into a static
library by running

```bash
make
```

## API

## Types

### map_status

```C
typedef enum {
  map_ok,
  map_exe_path_read_failed,
  map_failed_to_open_thp_file,
  map_invalid_regex,
  map_invalid_region_address,
  map_malformed_thp_file,
  map_malformed_maps_file,
  map_maps_open_failed,
  map_mover_overlaps,
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
} map_status;
```

A value in this enum is returned by all APIs provided. It indicates whether the
operation succeeded (`map_ok`) or the failure mode otherwise.

## Macros

### MAP_STATUS_STR

```C
#define MAP_STATUS_STR(status)
```

Maps a `map_status` to its corresponding verbose textual explanation.

### MAP_STATUS_STR_SHORT

```C
#define MAP_STATUS_STR_SHORT(status)
```

Maps a `map_status` to its corresponding terse textual explanation.

## APIs

### MapStaticCodeToLargePages

```C
map_status MapStaticCodeToLargePages();
```

Attempts to map an application's `.text` region to large pages.

If the region is not aligned to 2 MiB then the portion of the page that lies
below the first multiple of 2 MiB remains mapped to small pages. Likewise, if
the region does not end at an address that is a multiple of 2 MiB, the remainder
of the region will remain mapped to small pages. The portion in-between will be
mapped to large pages.

### MapDSOToLargePages

```C
map_status MapDSOToLargePages(const char* lib_regex);
```

- `[in] lib_regex`: A string containing a regular expression to be used against
the process' maps file.

Retrieves an address range from the process' maps file associated with a DSO
whose name matches `lib_regex` and attempts to map it to large pages.

If the region is not aligned to 2 MiB then the portion of the page that lies
below the first multiple of 2 MiB remains mapped to small pages. Likewise, if
the region does not end at an address that is a multiple of 2 MiB, the remainder
of the region will remain mapped to small pages. The portion in-between will be
mapped to large pages.

### MapStaticCodeRangeToLargePages

```C
map_status MapStaticCodeRangeToLargePages(void* from, void* to);
```

- `[in] from`: A starting address from which to attempt to map to large pages.
- `[in] to`: An ending address up to which to attempt to map to large pages.

Attempts to map the given address range to large pages.

If the region is not aligned to 2 MiB then the portion of the page that lies
below the first multiple of 2 MiB remains mapped to small pages. Likewise, if
the region does not end at an address that is a multiple of 2 MiB, the remainder
of the region will remain mapped to small pages. The portion in-between will be
mapped to large pages.

### IsLargePagesEnabled

```C
map_status IsLargePagesEnabled(bool* result);
```

- `[out] result`: Whether large pages are enabled.

Performs a platform-dependent check to determine whether it is possible to map to
large pages and stores the result of the check in `result`.

### MapStatusStr

```C
const char* MapStatusStr(map_status status, bool fulltext);
```

- `[in] status`: The `map_status` for which to retrieve the textual error
message.
- `[in] fulltext`: Whether to retrieve the verbose message (`true`) or a terser
message (`false`)
- **Returns**: A string containing the textual error message. The string is owned by
the implementation and must not be freed.
