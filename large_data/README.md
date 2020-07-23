# Reference Implementation for Utilizing Large Pages for Data
This directory contains a simple reference implementation for automating the process
of utilizing explicit huge pages for Data.


# APIs
```
* bool iodlr_hp_enabled()
  Check whether explict huge pages is enabled on the system
  Returns true if Huge Pages is enabled on the system
* size_t iodlr_get_hp_size()
  Obtains the size of the explicit huge pages (2MB or 1GB) in bytes
* void * iodlr_allocate(size_t s, size_t pgsz)
  mmap size bytes with pgsz
* void iodlr_deallocate(char *d, size_t s)
  unmap
* int MapStaticCodeToLargePages(hotstart, hotend)
  Map region from hotstart to hotend to 2MB pages
  Returns -1 if an error occurs while mapping
```

# Test
``` 
* int64_t hptest()
  Allocate a SIZE buffer with Huge Pages, zero fill it, and stride through it at 4K stride touching each byte of the 4K region.
  Returns the cycles (measured by rdtsc) to execute the test.

* int64_t defaulttest()
  Allocate a SIZE buffer with 4K Pages, zero fill it, and stride through it at 4K stride touching each byte of the 4K region.
  Returns the cycles (measured by rdtsc) to execute the test.
```

# Infrastructure

The Linux kernel in modern distros has large pages feature enabled by default. To check whether this is true for your kernel, use the following command and look for output lines containing “huge”:
```
shell> cat /proc/meminfo | grep -i huge
HugePages_Total:       0
HugePages_Free:        0
HugePages_Rsvd:        0
HugePages_Surp:        0
Hugepagesize:       1048676 kB
```
The nonempty command output indicates that large page support is present, but the zero values indicate that no pages are configured for use. Also the kernel is configured to use 1GB pages

Set the number of pages to be used.
Each page is 1GB, so a value of 8 = 8GB.
This command actually allocates memory, so this much amount of memory must be available.
```
echo 8 > /proc/sys/vm/nr_hugepages
``` 

# Building
```
  make
```

# Testing
This test needs 8G memory and for the hptest it needs 8 * 1G pages or 4096 * 2MB pages allocated as hugepages (using `nr_hugepages`)
```
./data-large-reference 
hptest hpsize 2097152
Cycles for 2097152 = 4918657468
defaulttest default pagesize 4096
Cycles for 4096 = 10988167648
Huge Page Data Speedup = 2.23398
```
