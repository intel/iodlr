// Copyright (C) 2018 Intel Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom
// the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
// OR OTHER DEALINGS IN THE SOFTWARE.
//
// SPDX-License-Identifier: MIT
//
#include <assert.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <x86intrin.h>

#ifndef MAP_HUGETLB
# define MAP_HUGETLB 0x40000
#endif

#ifndef MAP_HUGE_1GB
# define MAP_HUGE_1GB (30 << 26)
#endif

# define FLAGS_1G MAP_ANONYMOUS | MAP_PRIVATE | MAP_HUGETLB | MAP_HUGE_1GB
# define FLAGS_2M MAP_ANONYMOUS | MAP_PRIVATE | MAP_HUGETLB
# define FLAGS_4K MAP_ANONYMOUS | MAP_PRIVATE


/* 8G memory allocation */
#define SIZE_8G 8ul << 30 
/* Divide it into 4k chunks */
#define NCHUNKS_8G (8589934592/4096)

/* 4G memory allocation */
#define SIZE_4G 4ul << 30 
/* Divide it into 4k chunks */
#define NCHUNKS_4G (4294967296/4096)

/* 2G memory allocation */
#define SIZE_2G 2ul << 30 
/* Divide it into 4k chunks */
#define NCHUNKS_2G (2147483648/4096)

#define SIZE SIZE_8G
#define NCHUNKS NCHUNKS_8G


#include <climits>
#include <cstring>
#include <iostream>
#include <fstream>
#include <sstream>


#include <unistd.h>
size_t iodlr_get_default_page_size() {
return (size_t)(sysconf(_SC_PAGESIZE));
}

using std::string;
using std::ifstream;
using std::istringstream;
using std::cout;
using std::getline;

uint64_t iodlr_procmeminfo(string key) {
    ifstream ifs("/proc/meminfo");
    string map_line;

    while(getline(ifs,map_line)){
        istringstream iss(map_line);
        string keyname;
        uint64_t value;
        string kb;
        iss >> keyname;
        iss >> value;
        iss >> kb;
//        cout << keyname << " " << value << "\n";
        if (keyname == key) {
                return value;
        }
    }
    return -1; // nothing found

}

bool iodlr_hp_enabled() {
    uint64_t val = iodlr_procmeminfo("HugePages_Total:");
    if (val > 0 )
        return true;
    else 
        return false;
}

size_t iodlr_get_hp_size() {
    uint64_t val = iodlr_procmeminfo("Hugepagesize:");
    if (val > 0) {
        return val * 1024;
    }
    return -1;
}


void * iodlr_allocate(size_t s, size_t pgsz) {
    int flags=FLAGS_4K;
    void *data;
    if (pgsz ==  1048576* 1024)
       flags = FLAGS_1G;
    else if (pgsz == 2048*1024)
       flags = FLAGS_2M;

    data = mmap(NULL, s,
                         PROT_READ | PROT_WRITE, flags,
                         -1, 0);
    assert(data != MAP_FAILED);
    return data;
}

void iodlr_deallocate(char *d, size_t s) {
    int i;
    i = munmap (d, s);
    assert (i != -1);
}

void zerofill(char *d, size_t s) {
    memset (d, 0, s);
}

void touch(char *d, size_t stride, size_t index, size_t size) {

    char a;
    int i;
    assert (stride < size);

    for (i=0; i < NCHUNKS; i++) {
        assert (i*stride + index < size);
        a = d[i*stride+index];
    }
}

int64_t dotest(size_t s) {
        int i;
        size_t stride = (SIZE)/NCHUNKS;
        uint64_t start, end;
        start = __rdtsc();
        char *data = (char *)iodlr_allocate(SIZE, s);
        zerofill(data, SIZE);
        for (i=0; i < 4096; i++) {
          touch(data, stride, i, SIZE);
        }
        iodlr_deallocate(data, SIZE);
        end = __rdtsc();
        cout << "Cycles for " << s << " = " << (end - start) << "\n";
        return (end - start);
}

int64_t hptest() {
        bool lp = iodlr_hp_enabled();
        if (lp == true) {
          size_t l = iodlr_get_hp_size();
          cout << "hptest hpsize " << l << "\n";
          return dotest(l);
        }
        return -1;
}

int64_t defaulttest() {
        size_t d = iodlr_get_default_page_size();
        cout << "defaulttest default pagesize " << d << "\n";
        return dotest(d);
}


int main (int argc, char **argv)
{
        (void)argc;
        (void)argv;
        int64_t hpt, dt;
        hpt = hptest();
        dt = defaulttest();
        cout << "Huge Page Data Speedup = " << (double) dt/ (double)hpt << "\n";
}



