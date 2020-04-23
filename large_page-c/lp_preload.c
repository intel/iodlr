#include <stdio.h>
#include <stdlib.h>
#include "large_page.h"

void __attribute__((constructor)) map_to_large_pages() {
  bool is_enabled = true;
  map_status status = IsLargePagesEnabled(&is_enabled);
  if (status != map_ok) goto fail;

  if (!is_enabled) goto fail;

  status = MapStaticCodeToLargePages();
  if (status != map_ok) goto fail;
  return;
fail:
  if (status == map_ok) {
    if (!is_enabled)
      fprintf(stderr,
              "Mapping to large pages in not enabled on your system. "
              "Make sure /sys/kernel/mm/transparent_hugepage/enabled is set to "
              "'madvise' or 'enabled'\n");
  } else {
    fprintf(stderr,
            "Mapping to large pages failed: %s\n",
            MapStatusStr(status, true));
  }
  abort();
}
