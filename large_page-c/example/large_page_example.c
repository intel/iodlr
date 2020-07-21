#include "large_page.h"
#include <stdio.h>

int main() {
  map_status status;
  bool is_enabled;

  status = IsLargePagesEnabled(&is_enabled);
  if (status != map_ok) {
    fprintf(stderr, "Failed to check enablement: %s\n",
            MAP_STATUS_STR(status));
    return status;
  }

  if (is_enabled) {
    printf("Transparent Huge Pages are enabled, mapping...\n");
    status = MapStaticCodeToLargePages();
    if (status != map_ok) {
      fprintf(stderr, "Failed to map: %s\n", MAP_STATUS_STR(status));
      return status;
    }
    printf("Success\n");
    return 0;
  }
  fprintf(stderr, "Transparent Huge Pages are not enabled\n");
  return -1;
}
