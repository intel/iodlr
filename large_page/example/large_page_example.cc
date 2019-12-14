#include <iostream>
#include "large_page.h"

using std::cout;
using std::cerr;
using std::endl;

int main() {
  largepage::MapStatus status;
  bool is_enabled;

  status = largepage::IsLargePagesEnabled(&is_enabled);
  if (status != largepage::map_ok) {
    cerr << "Failed to check enablement: "
         << largepage::MapStatusStr(status) << endl;
    return status;
  }

  if (is_enabled) {
    cout << "Transparent Huge Pages are enabled, mapping ..." << endl;
    status = largepage::MapStaticCodeToLargePages();
    if (status != largepage::map_ok) {
      cerr << "Failed to map: " << largepage::MapStatusStr(status) << endl;
      return status;
    }
    cout << "Success !" << endl;
    return 0;
  }
  cerr << "Transparent Huge Pages are not enabled" << endl;
  return -1;
}
