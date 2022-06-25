ARG baseimage=wp_base_https
FROM $baseimage

LABEL authors="ping.zhao@intel.com"

ARG IPP_CRYPTO_TAG=ippcp_2021.3
ARG QAT_ENGINE_TAG=v0.6.1
ARG ASYNCH_NGINX_TAG=v0.4.3
ARG PHP_VER

COPY files/perf.fdata /home/${USERNAME}/oss-performance

ARG zendlp=1
ARG bolt=1
ARG iodlrlp=1
ARG query=1

# Optimization: Set environment variable to have zend use large pages
ENV USE_ZEND_ALLOC_HUGE_PAGES="$zendlp" 

# Build php for bolting

RUN sudo -E apt-get update && sudo -E apt-get install -y gcc-7 g++-7

RUN if [ "$bolt" = "1" ] ; then \
    sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-7 7 && \
    sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-7 7 && \
    cd /home/${USERNAME}/oss-performance && \
    git clone https://github.com/php/php-src.git && \
    cd /home/${USERNAME}/oss-performance/php-src && \
    git checkout PHP-$PHP_VER && \ 
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
    rm /home/${USERNAME}/oss-performance/pdo_mysql.so /home/${USERNAME}/oss-performance/mysqli.so 2> /dev/null; \
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
RUN if [ "$iodlrlp" = "1" ] ; then \
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
RUN if [ "$query" = "1" ] ; then sudo cp /home/${USERNAME}/${mariadbconf}-bkm.j2 /etc/mysql/my.cnf ; fi

# Bolt with https fdata
WORKDIR /home/${USERNAME}/oss-performance
COPY files/perf.fdata /home/${USERNAME}/oss-performance
RUN ./llvm-bolt ./php-fpm -o ./php-fpm.bolt -data=perf.fdata -reorder-blocks=cache+ -reorder-functions=hfsort+ -split-functions=3 -split-all-cold -split-eh -dyno-stats

USER root

RUN apt-get update && \
    apt-get install -y libtool nasm

# Build/Install IPP cyrypto library for the multi-buffer support
WORKDIR /home/${USERNAME}/temp
RUN git clone https://github.com/intel/ipp-crypto.git && \
    cd ipp-crypto && \
    git checkout $IPP_CRYPTO_TAG && \
    cd sources/ippcp/crypto_mb && \
    CXX=g++-9 CC=gcc-9 cmake . -B./build -DOPENSSL_INCLUDE_DIR=/home/${USERNAME}/openssl_install/include/ -DOPENSSL_LIBRARIES=/home/${USERNAME}/openssl_install/ -DOPENSSL_ROOT_DIR=/home/${USERNAME}/temp/openssl/ && \
    cd build && \
    make -j && \
    mkdir -p /home/${USERNAME}/crypto_mb/lib && \
    ln -s /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/build/bin/libcrypto_mb.so /home/${USERNAME}/crypto_mb/lib/ && \
    ln -s /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/include /home/${USERNAME}/crypto_mb/include

# Build/install IPSec_MB library
ARG IPSEC_MB_TAG=v0.55
WORKDIR /home/${USERNAME}/temp
RUN mkdir ipsec && \
    git clone https://github.com/intel/intel-ipsec-mb.git && \
    cd intel-ipsec-mb/ && \
    git checkout $IPSEC_MB_TAG && \
    make -j && \
    make install PREFIX=/home/${USERNAME}/temp/ipsec

# Build/Install QAT engine 
WORKDIR /home/${USERNAME}/temp
RUN git clone  https://github.com/intel/QAT_Engine.git qat_engine && \
    cd qat_engine && \
    git checkout $QAT_ENGINE_TAG && \
    ./autogen.sh && \
    ./configure \
        --enable-multibuff_offload \
        --enable-ipsec_offload \
        --with-ipsec_install_dir=/home/${USERNAME}/temp/ipsec \
        --with-multibuff_install_dir=/home/${USERNAME}/crypto_mb \
        --with-openssl_install_dir=/home/${USERNAME}/openssl_install && \
    make -j && \
    make install

# Build/Install AYNCH NGINX
WORKDIR /home/${USERNAME}/nginx_build
RUN git clone https://github.com/intel/asynch_mode_nginx.git nginx && \
    cd nginx && \
    git checkout $ASYNCH_NGINX_TAG && \
    ./configure --prefix=/usr/ \
        --with-http_ssl_module --add-dynamic-module=modules/nginx_qat_module \
        '--with-cc-opt=-DNGX_SECURE_MEM \
        -I /home/${USERNAME}/openssl_install/include \
        -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0' \
        '--with-ld-opt=-Wl,-rpath=/home/${USERNAME}/openssl_install/lib \
        -L /home/${USERNAME}/openssl_install/lib' && \
    make -j && \
    make install 
WORKDIR /home/${USERNAME}
RUN rm -rf ./nginx_build

WORKDIR /home/${USERNAME}/oss-performance

COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx

RUN ln -s /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/build/bin/libcrypto_mb.so.11.1 /usr/lib/libcrypto_mb.so.11

USER ${USERNAME}
