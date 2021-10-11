#define _GNU_SOURCE
#include <link.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <regex.h>
#include "large_page.h"

void printErr (map_status status, const char * lib) {
  fprintf(stderr,
    "Mapping to large pages failed for %s: %s\n", lib,
    MapStatusStr(status, true));
}

static int tryMapAllDSOs(struct dl_phdr_info* hdr, size_t size, void* data) {
  regex_t * ignoreReg = (regex_t *)data;
  const char * lib = hdr->dlpi_name;
  if (lib && lib[0] != 0) {
    if (ignoreReg != NULL && regexec(ignoreReg, lib, 0, NULL, 0) == 0) {
      fprintf(stderr, "Ignoring %s\n", lib);
    } else {
      fprintf(stderr, "Enabling large code pages for %s ", lib);
      fflush(stderr); // flush output before a possible error
      map_status status = MapDSOToLargePages(lib);
      if (status == map_ok) {
        fprintf(stderr, " - success.\n");
      } else {
        fprintf(stderr, "\n");
        printErr(status, lib);
      }
    }
  }
  return 0;
}


void __attribute__((constructor)) map_to_large_pages() {
  bool is_enabled = true;
  map_status status = IsLargePagesEnabled(&is_enabled);
  if (status != map_ok) goto fail;

  if (!is_enabled) goto fail;

  status = MapStaticCodeToLargePages();
  if (status != map_ok) {
    printErr(status, "static code");
  }

  regex_t ignoreReg;
  const char * ignoreStr = secure_getenv("LP_IGNORE");
  if (ignoreStr == NULL || regcomp(&ignoreReg, ignoreStr, REG_EXTENDED) != 0) {
    dl_iterate_phdr(tryMapAllDSOs, NULL);
  } else {
    dl_iterate_phdr(tryMapAllDSOs, &ignoreReg);
    regfree(&ignoreReg);
  }

  return;
fail:
  if (status == map_ok) {
    if (!is_enabled)
      fprintf(stderr,
              "Mapping to large pages in not enabled on your system. "
              "Make sure /sys/kernel/mm/transparent_hugepage/enabled is set to "
              "'madvise' or 'enabled' "
	      "Or explicit hugepages of supported size is enabled with "
	      "+ve number in /proc/sys/vm/nr_hugepages. \n");
  } else {
    fprintf(stderr,
            "Mapping to large pages failed: %s\n",
            MapStatusStr(status, true));
  }
}
