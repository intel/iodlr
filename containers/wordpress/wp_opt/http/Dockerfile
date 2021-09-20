# Copyright (C) 2021 Intel Corporation
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files
# (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so, 
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
# OR OTHER DEALINGS IN THE SOFTWARE.
#
# SPDX-License-Identifier: MIT
ARG baseimage=wp_base
FROM $baseimage
LABEL authors="nitin.tekchandani@intel.com,lin.a.yang@intel.com,uttam.c.pawar@intel.com"

SHELL ["/bin/bash", "-c"]

COPY files/perf.fdata /home/${USERNAME}/oss-performance

ARG zendlp=1
ARG bolt=1
ARG iodlrlp=1
ARG query=1

# Optimization: Set environment variable to have zend use large pages
ENV USE_ZEND_ALLOC_HUGE_PAGES="$zendlp" 

# Build php 7.4.16 for bolting

RUN if [[ "$bolt" == "1" ]] ; then \
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 && \
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 && \
    cd /home/${USERNAME}/oss-performance && \
    git clone https://github.com/php/php-src.git && \
    cd /home/${USERNAME}/oss-performance/php-src && \
    git checkout PHP-7.4.16 && \ 
    ./buildconf --force && \
    ./configure --enable-fpm --with-mysqli --with-pdo-mysql --enable-pcntl && \
    EXTRA_CFLAGS="-g" LDFLAGS="-Wl,--emit-relocs,-znow" make -j && \
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 9 && \
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-9 9 && \
# Build llvm-bolt
    cd /home/${USERNAME}/oss-performance && \
    git clone https://github.com/llvm-mirror/llvm llvm && \
    cd llvm/tools && \
    git checkout -b llvm-bolt f137ed238db11440f03083b1c88b7ffc0f4af65e && \
    git clone https://github.com/facebookincubator/BOLT llvm-bolt && \
    cd llvm-bolt && \
    git checkout tags/v1.0.1 && \
    cd .. && \
    cd .. && \
    patch -p 1 < tools/llvm-bolt/llvm.patch && \
    cd .. && \
    mkdir build && \
    cd build && \
    cmake -G Ninja ../llvm -DLLVM_TARGETS_TO_BUILD="X86;AArch64" -DCMAKE_BUILD_TYPE=Release -DLLVM_ENABLE_ASSERTIONS=ON && \
    ninja && \
# Optimization: Bolt php-fpm binary
    cd /home/${USERNAME}/oss-performance && \
    cp ./build/bin/llvm-bolt /home/${USERNAME}/oss-performance && \
    cp ./php-src/sapi/fpm/php-fpm /home/${USERNAME}/oss-performance && \
    cp /home/${USERNAME}/oss-performance/php-src/modules/opcache.so /home/${USERNAME}/oss-performance && \
    ./llvm-bolt ./php-fpm -o ./php-fpm.bolt -data=perf.fdata -reorder-blocks=cache+ -reorder-functions=hfsort+ -split-functions=3 -split-all-cold -split-eh -dyno-stats && \
    sed -i "s/\/usr\/sbin\/php-fpm7\.4/\/home\/${USERNAME}\/oss-performance\/php-fpm\.bolt/" quickrun.sh && \
    sed -i "s/zend_extension\=opcache\.so/zend_extension\=\/home\/${USERNAME}\/oss-performance\/opcache.so/" conf/php.ini && \
# Cleanup: Remove llvm build and perf.fdata
    rm -rf /home/${USERNAME}/oss-performance/llvm && \
    rm -rf /home/${USERNAME}/oss-performance/build && \
# Cleanup: move php binaries and remove php clone and build files
    rm -rf /home/${USERNAME}/oss-performance/php-src ; \
    fi

# Optimization: Build and install iodlr huge pages library (commit_id: 01f4985) for use with mariadb
RUN if [[ "$iodlrlp" == "1" ]] ; then \
    cd /home/${USERNAME} && \
    git clone https://github.com/intel/iodlr && \
    cd iodlr && \
    git checkout 01f4985 && \
    cd large_page-c && \
    make -f Makefile.preload && \
    sudo cp liblppreload.so /usr/lib/ && \
    sudo sed -i 's/\/usr\/bin\/mysqld_safe/LD_PRELOAD=\/usr\/lib\/liblppreload.so \/usr\/bin\/mysqld_safe/' /etc/init.d/mysql && \
    rm -rf /home/${USERNAME}/iodlr/ ; \
    fi

ARG mariadbconf=1s
# Optimization: Query cache optimization for single socket operation (unless over-ridden)
RUN if [[ "$query" == "1" ]] ; then sudo cp /home/${USERNAME}/${mariadbconf}-bkm.j2 /etc/mysql/my.cnf ; fi

WORKDIR /home/${USERNAME}/oss-performance
