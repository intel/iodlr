#include "large_page.h"
#include <stdio.h>

int main() {
  if (IsLargePagesEnabled() == true) {
    printf("Transparent Huge Pages are enabled, mapping...\n");
    if (MapStaticCodeToLargePages() == -1) {
      printf("Failed\n");
    } else {
      printf("Success\n");
    }
  } else {
      printf("Transparent Huge Pages are not enabled\n");
  }
  return 0;
}
