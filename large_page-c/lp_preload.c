#include <stdio.h>
#include "large_page.h"

void __attribute__((constructor)) map_to_large_pages() {
  bool is_enabled;
  map_status status = IsLargePagesEnabled(&is_enabled);
  if (status != map_ok) {
    fprintf(stderr,
            "Failed to determine if large pages is enabled: %s\n",
            MapStatusStr(status, true));
  }

  if (!is_enabled) {
    fprintf(stderr, "Mapping to large pages is not enabled\n");
    return;
  }

  status = MapStaticCodeToLargePages();
  if (status != map_ok) {
    fprintf(stderr,
            "Failed to map to large pages: %s\n",
            MapStatusStr(status, true));
    return;
  }

  fprintf(stderr, "Successfully mapped code to large pages\n");
}
