# Reference Implementation for Utilizing Large Pages

This directory contains a reference implementation for automating the process
of re-mapping code to transparent huge pages. It contains a target for building
a static library that can be used along with the header files in a larger
project, and a target for building a shared library that can be loaded into a
process using `LD_PRELOAD`, at which point it will re-map the `.text` segment of
the executable and dependent shared libraries.

## Building The Static Library

The APIs provided by the reference implementation can be built into a static
library by running

```bash
make
```

This will create `liblarge_page.a` in the current directory.

## Building The Shared Library

The shared library can be built by running

```bash
make -f Makefile.preload
```

This will create `liblppreload.so` in the current directory. This file should
then be copied to `/usr/lib64`.

### Using The Shared Library

`liblppreload.so` can be added to any process on the command line. The example
below illustrates the use of the shared library with Node.js:

```bash
LD_PRELOAD=/usr/lib64/liblppreload.so node
```

If you want to exclude some libraries from being moved to large pages use `LP_IGNORE`
parameter which is a regex string to specify which libraries to ignore. An example
ignoring libc and libabc:

```bash
LD_PRELOAD=/usr/lib64/liblppreload.so LP_IGNORE='(libc)|(libabc)' node
```

### Modifying A `systemd` Service

`systemd` service files are responsible for running processes as daemons during
startup. They are usually located in `/etc/systemd/system`. They consist of
several sections, including a section named `[Service]`. In this section
environment variables are specified which will be set during the execution of
the processes listed in the file. An environment variable can be added to this
section as follows:

```
[Service]
Environment=LD_PRELOAD=/usr/lib64/liblppreload.so
```

Note that the location of `liblppreload.so` should be a system library path
(`/usr/lib64` in the above example) otherwise `systemd` may refuse to load the
library.

After this modification is made, `systemd` must be instructed to reload its
configuration and the corresponding daemon must be restarted. The `systemd`
configuration can be reloaded by issuing

```
systemctl daemon-reload
```
as root.

Afterwards the daemon whose `.service` file was modified can be restarted by
issuing

```
systemctl restart <daemon>
```

as root, where `<daemon>` is the name of the daemon whose service file was
modified.

**NOTE:** Since `liblppreload.so` is added onto the daemon process, it is unable
to use whatever logging facilities the process may have. If it fails to re-map
the process' code to large pages, it will issue an error on `stderr`. The daemon
should be run from the command line without forking into the background in order
to determine any potential problems with the re-mapping. Taking `mysqld` as an
example, running

```
LD_PRELOAD=/usr/lib64/liblppreload.so mysqld --help
```

will reveal any issues related to re-mapping the code.

Examining the daemon's `/proc/<pid>/smaps` file can be used as a final check to
ensure that the code was re-mapped to large pages. See the [smaps][]
documentation for details about the format of `/proc/<pid>/smaps`. Taking
`mysqld` as an example, its pid can be obtained by running

```bash
$ ps ax | grep mysqld
 32732 pts/7    S+     0:00 grep --color=auto mysqld
 44982 ?        Ssl  254:44 /usr/sbin/mysqld
```

This reveals that `44982` is `mysqld`'s pid. Running

```bash
less /proc/44982/smaps
```

and looking for `AnonHugePages` will reveal whether any portion of
`/usr/sbin/mysqld`'s code was re-mapped to large pages, because the number
appearing after `AnonHugePages` will be non-zero.

## API

## Types

### map_status

```C
typedef enum {
  map_ok,
  map_failed_to_open_thp_file,
  map_invalid_regex,
  map_invalid_region_address,
  map_malformed_thp_file,
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
  map_open_exe_failed,
  map_see_errno_close_exe_failed,
  map_read_exe_header_failed,
  map_see_errno_seek_exe_sheaders_failed,
  map_read_exe_sheaders_failed,
  map_see_errno_seek_exe_string_table_failed,
  map_read_exe_string_table_failed,
  map_not_enough_explicit_hugepages_are_allocated
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
large pages and stores the result of the check in `result.
It supports both transparent and explicit hugepages. By default it will
use transparent hugepages.
To use explicit huge pages use an environment variable as shown below,
`
```C
$ export IODLR_USE_EXPLICIT_HP=1
```
`[error/warning/info]`: If not enough pages are available. User will also be
informed about how many pages a program would need (code section only). Please 
check and update /proc/sys/vm/nr_hugepages as required.


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

[smaps]: https://github.com/torvalds/linux/blob/v5.6/Documentation/filesystems/proc.txt#L421
