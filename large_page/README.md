# Reference Implementation for Utilizing Large Pages
This directory contains a reference implementation for automating the process
of utilizing transparent huge pages.

# APIs
```
* bool IsLargePagesEnabled()
  Check whether transparent huge pages is enabled on the system
  Returns true if THP is enabled on the system
* int MapStaticCodeToLargePages()
  Map entire .text segment of the executable to 2MB pages
  Returns -1 if an error occurs while mapping
* int MapStaticCodeToLargePages(hotstart, hotend)
  Map region from hotstart to hotend to 2MB pages
  Returns -1 if an error occurs while mapping
```

# Building liblarge_page.a:
```
  make
```
