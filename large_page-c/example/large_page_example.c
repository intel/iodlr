#include "large_page.h"
#include <stdio.h>

static char* map_status_text[] = {
  "ok",
  "failed to read executable path file",
  "failed to open thp enablement status file",
  "invalid regex",
  "invalid region boundaries",
  "malformed thp enablement status file",
  "failed to open maps file",
  "the remapping function is part of the region",
  "regex was NULL",
  "map region not found",
  "map region too small",
  "see errno",
  "madvise for destination failed",
  "madvise for destination and unmapping of temporary failed",
  "madvise for destination and unmappings failed",
  "madvise for destination and unmapping of destination failed",
  "mapping of destination failed",
  "mapping of destination and unmapping of temporary failed",
  "mprotect failed",
  "mprotect and unmappings failed",
  "mprotect and unmapping of destination failed",
  "mprotect and unmapping of temporary failed",
};

int main() {
  map_status status;
  bool is_enabled;

  status = IsLargePagesEnabled(&is_enabled);
  if (status != map_ok) {
    fprintf(stderr, "Failed to check enablement: %s\n", map_status_text[status]);
    return status;
  }

  if (is_enabled) {
    printf("Transparent Huge Pages are enabled, mapping...\n");
    status = MapStaticCodeToLargePages();
    if (status != map_ok) {
      fprintf(stderr, "Failed to map: %s\n", map_status_text[status]);
      return status;
    }
    printf("Success\n");
  } else {
      printf("Transparent Huge Pages are not enabled\n");
  }
  return 0;
}
