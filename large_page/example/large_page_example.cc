#include <iostream>
#include "large_page.h"

int main()
{
   if (IsLargePagesEnabled)
     std::cout<<"Transparent Huge Pages is enabled"<<std::endl;
   else
     std::cout<<"Transparent Huge Pages is enabled"<<std::endl;
   return 0;
}
