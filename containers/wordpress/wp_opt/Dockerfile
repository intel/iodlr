ARG baseimage
ARG PHP_VER
ARG INSTALL_DIR="/pkg_install"

ARG IPP_CRYPTO_TAG=ippcp_2021.3
ARG QAT_ENGINE_TAG=v0.6.1
ARG ASYNCH_NGINX_TAG=v0.4.7
ARG IPSEC_MB_TAG=v0.55


# ----- TEMP container -----
# used for copying built php-fpm and opcache.so
# for bolting.
# ----- php-fpm build container -----
FROM php:${PHP_VER}-fpm AS php-fpm
MAINTAINER "anthony.s.pray@intel.com"
ARG PHP_VER

ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime ;\
 echo $TZ > /etc/timezone
RUN apt-get update; \
 apt-get install -y \
 libonig-dev \
 libsqlite3-dev \
 zlib1g-dev \
 libpng-dev \
 libssl-dev \
 libxml2-dev;

WORKDIR /usr/src/php 
COPY files/0001-BOLT-PHP${PHP_VER}-GCC-option.patch ./
COPY files/0001-JIT-buffer-relocation-and-2-PHP${PHP_VER}-performance.patch ./
RUN docker-php-source extract; \
  patch -p1 < 0001-BOLT-PHP${PHP_VER}-GCC-option.patch; \
#  patch -p1 < 0001-JIT-buffer-relocation-and-2-PHP${PHP_VER}-performance.patch; \
  ./configure \
  --enable-fpm \
  --with-mysqli \
  --with-pdo-mysql \
  --enable-pcntl; \
 EXTRA_CFLAGS="-g -fno-reorder-blocks-and-partition" \
 LDFLAGS="-Wl,--emit-relocs,-znow" \
 make -j; \
 cp /usr/src/php/sapi/fpm/php-fpm /php-fpm;\
 cp /usr/src/php/modules/opcache.so /opcache.so;\
 docker-php-source delete;

# ----- llvm-bolt build container -----
FROM ubuntu:20.04 AS llvm-bolt
MAINTAINER "anthony.s.pray@intel.com"
ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime ;\
 echo $TZ > /etc/timezone
RUN apt-get update;\
    apt-get install -y --no-install-recommends \
     ca-certificates \
     git \
     build-essential \
     cmake \
     ninja-build \
     python3 \
     libjemalloc-dev \
     python3-psutil; \
    rm -rf /var/lib/apt/lists

WORKDIR /home/bolt
RUN git clone --depth 1 -b llvmorg-14.0.1 https://github.com/llvm/llvm-project

ARG LLVM_TARGETS="X86"
RUN mkdir build; \
    cd build; \
    cmake -G Ninja ../llvm-project/llvm \
      -DLLVM_ENABLE_PROJECTS="bolt" \
      -DLLVM_TARGETS_TO_BUILD=${LLVM_TARGETS} \
      -DCMAKE_BUILD_TYPE=Release \
      -DLLVM_ENABLE_ASSERTIONS=ON \
      -DCMAKE_EXE_LINKER_FLAGS="-Wl,--push-state -Wl,-whole-archive -ljemalloc_pic -Wl,--pop-state -lpthread -lstdc++ -lm -ldl" \
      -DCMAKE_INSTALL_PREFIX=/home/bolt/install; \
    ninja check-bolt; \
    ninja install-llvm-bolt \
    install-perf2bolt \
    install-merge-fdata \
    install-llvm-boltdiff \
    install-bolt_rt


# ----- bolting container -----
FROM ubuntu:20.04 as bolter
WORKDIR /opt
ARG PHP_VER
COPY --from=llvm-bolt /home/bolt/install /usr/local
COPY --from=php-fpm /php-fpm /opt/
COPY --from=php-fpm /opcache.so /opt/
COPY files/${PHP_VER}-perf.fdata /opt/perf.fdata
RUN printf '\nProcessing llvm-bolting...\n perf.fdata -> php-fpm.bolt\n';\
llvm-bolt \
 /opt/php-fpm \
 -o /opt/php-fpm.bolt \
 -data=/opt/perf.fdata \
 -reorder-blocks=cache+ \
 -reorder-functions=hfsort+ \
 -split-functions=3 \
 -split-all-cold \
 -split-eh \
 -dyno-stats;


# ----- The container for building the components-----
# build siege, openssl, async Nginx ...
# to copy the binary to worker container
# ----------------------------------------------------
FROM $baseimage AS dep-components
ARG DEBIAN_FRONTEND="noninteractive"
ARG TZ="America/Los_Angeles"
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

ARG INSTALL_DIR
USER root
RUN apt-get update && apt-get install -y \
    software-properties-common \
    gcc-10 \
    g++-10 \
    software-properties-common \
    apt-transport-https \
    git \
    automake \
    gcc \
    make \
    cmake \
    wget \
    libevent-dev \
    vim \
    python3-pip \
    sudo \
    autotools-dev \
    autoconf \
    build-essential \
    zlib1g \
    zlib1g-dev \
    sysstat \
    linux-tools-common \
    ruby \
    python3-dev \
    libssl-dev \
    ninja-build \
    libjemalloc-dev \
    pkg-config \
    build-essential \
    autoconf \
    bison \ 
    re2c \
    libxml2-dev \
    libsqlite3-dev \
    php-mysql \
    php \
    libpcre3 \
    libpcre3-dev \
    libonig5 \
    libtool \
    nasm

# Build/Install IPP cyrypto library for the multi-buffer support
WORKDIR /home/${USERNAME}/temp
ARG IPP_CRYPTO_TAG
RUN git clone --depth 1 -b $IPP_CRYPTO_TAG https://github.com/intel/ipp-crypto.git && \
    cd ipp-crypto && \
    cd sources/ippcp/crypto_mb && \
    CXX=g++-10 CC=gcc-10 cmake . -B./build -DOPENSSL_INCLUDE_DIR=/home/${USERNAME}/openssl_install/include/ -DOPENSSL_LIBRARIES=/home/${USERNAME}/openssl_install/ -DOPENSSL_ROOT_DIR=/home/${USERNAME}/temp/openssl/ && \
    cd build && \
    make -j && \
    mkdir -p /home/${USERNAME}/crypto_mb/lib && \
    cp /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/build/bin/libcrypto_mb.so /home/${USERNAME}/crypto_mb/lib/ && \
    cp -r /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/include /home/${USERNAME}/crypto_mb/
#    cp -r /home/${USERNAME}/crypto_mb $INSTALL_DIR/

# Build/install IPSec_MB library
ARG IPSEC_MB_TAG
WORKDIR /home/${USERNAME}/temp
RUN mkdir ipsec && \
    git clone --depth 1 -b $IPSEC_MB_TAG https://github.com/intel/intel-ipsec-mb.git && \
    cd intel-ipsec-mb/ && \
    make -j && \
#    make install PREFIX=$INSTALL_DIR/ipsec && \
    make install PREFIX=/home/${USERNAME}/temp/ipsec


# Build/Install QAT engine
ARG QAT_ENGINE_TAG
WORKDIR /home/${USERNAME}/temp
RUN git clone --depth 1 -b $QAT_ENGINE_TAG https://github.com/intel/QAT_Engine.git qat_engine && \
    cd qat_engine && \
    ./autogen.sh && \
    ./configure \
        --enable-qat_sw \
        --enable-multibuff_offload \
        --enable-ipsec_offload \
        --with-ipsec_install_dir=/home/${USERNAME}/temp/ipsec \
        --with-multibuff_install_dir=/home/${USERNAME}/crypto_mb \
        --with-openssl_install_dir=/home/${USERNAME}/openssl_install && \
    make -j && \
    make install

ARG ASYNCH_NGINX_TAG
# Build/Install AYNCH NGINX, no QAT
WORKDIR /home/${USERNAME}/nginx_build
RUN rm -rf nginx && \
    git clone --depth 1 -b $ASYNCH_NGINX_TAG https://github.com/intel/asynch_mode_nginx.git nginx && \
    cd nginx && \
    ./configure --prefix=/usr/ \
        --with-http_ssl_module --add-dynamic-module=modules/nginx_qat_module \
        --with-cc-opt="-DNGX_SECURE_MEM \
        -I /home/${USERNAME}/openssl_install/include \
        -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0" \
        --with-ld-opt="-Wl,-rpath=/home/${USERNAME}/openssl_install/lib \
        -L /home/${USERNAME}/openssl_install/lib" && \
    make -j && \
    make install DESTDIR=$INSTALL_DIR && \
    rm -rf /home/${USERNAME}/nginx_build


# --------------- opt container ---------------
FROM $baseimage
MAINTAINER "ping.zhao@intel.com"

ARG INSTALL_DIR

RUN sudo -E apt-get update && sudo -E apt-get install -y \
    software-properties-common \
    gcc-10 \
    g++-10 \
    software-properties-common \
    apt-transport-https \
    git \
    automake \
    gcc \
    make \
    cmake \
    libevent-dev \
    vim \
    python3-pip \
    sudo \
    autotools-dev \
    autoconf \
    libtool \
    nasm


# Binary copy AYNCH NGINX with QAT, 
COPY  --from=dep-components --chown=${USERNAME}:root $INSTALL_DIR /


WORKDIR /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx
COPY --from=bolter --chown=pkb:pkb /opt/php-fpm.bolt /home/${USERNAME}/oss-performance/php-fpm
COPY --from=bolter --chown=pkb:pkb /opt/opcache.so /home/${USERNAME}/oss-performance/



ARG IPP_CRYPTO_TAG
ARG QAT_ENGINE_TAG
ARG ASYNCH_NGINX_TAG
ARG IPSEC_MB_TAG

ARG iodlrlp=1
ARG query=1

# Optimization: Build and install iodlr huge pages library (commit_id: 01f4985) for use with mariadb
RUN if [ "$iodlrlp" = "1" ] ; then \
    cd /home/${USERNAME} && \
    git clone --depth 1 -b v1.0.0 https://github.com/intel/iodlr && \
    cd iodlr && \
    cd large_page-c && \
    make -f Makefile.preload && \
    sudo cp liblppreload.so /usr/lib/ && \
    sudo sed -i 's/\/usr\/bin\/mysqld_safe/LD_PRELOAD=\/usr\/lib\/liblppreload.so \/usr\/bin\/mysqld_safe/' /etc/init.d/mysql && \
    rm -rf /home/${USERNAME}/iodlr/ ; \
    fi

ARG mariadbconf=1s
# Optimization: Query cache optimization for single socket operation (unless over-ridden)
RUN if [ "$query" = "1" ] ; then sudo cp /home/${USERNAME}/${mariadbconf}-bkm.j2 /etc/mysql/my.cnf ; fi

USER root

# Build/Install IPP cyrypto library for the multi-buffer support
WORKDIR /home/${USERNAME}/temp
RUN git clone --depth 1 -b $IPP_CRYPTO_TAG https://github.com/intel/ipp-crypto.git && \
    cd ipp-crypto && \
    cd sources/ippcp/crypto_mb && \
    CXX=g++-10 CC=gcc-10 cmake . -B./build -DOPENSSL_INCLUDE_DIR=/home/${USERNAME}/openssl_install/include/ -DOPENSSL_LIBRARIES=/home/${USERNAME}/openssl_install/ -DOPENSSL_ROOT_DIR=/home/${USERNAME}/temp/openssl/ && \
    cd build && \
    make -j && \
    mkdir -p /home/${USERNAME}/crypto_mb/lib && \
    ln -s /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/build/bin/libcrypto_mb.so /home/${USERNAME}/crypto_mb/lib/ && \
    ln -s /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/include /home/${USERNAME}/crypto_mb/include

# Build/install IPSec_MB library
WORKDIR /home/${USERNAME}/temp
RUN rm -rf ipsec intel-ipsec-mb && \
    mkdir ipsec && \
    git clone --depth 1 -b $IPSEC_MB_TAG https://github.com/intel/intel-ipsec-mb.git && \
    cd intel-ipsec-mb/ && \
    make -j && \
    make install PREFIX=/home/${USERNAME}/temp/ipsec

# Build/Install QAT engine 
WORKDIR /home/${USERNAME}/temp
RUN git clone --depth 1 -b $QAT_ENGINE_TAG https://github.com/intel/QAT_Engine.git qat_engine && \
    cd qat_engine && \
    ./autogen.sh && \
    ./configure \
        --enable-qat_sw \
        --enable-multibuff_offload \
        --enable-ipsec_offload \
        --with-ipsec_install_dir=/home/${USERNAME}/temp/ipsec \
        --with-multibuff_install_dir=/home/${USERNAME}/crypto_mb \
        --with-openssl_install_dir=/home/${USERNAME}/openssl_install && \
    make -j && \
    make install


WORKDIR /home/${USERNAME}/oss-performance

RUN cp /home/${USERNAME}/temp/ipp-crypto/sources/ippcp/crypto_mb/build/bin/libcrypto_mb.so.11.1 /usr/lib/libcrypto_mb.so.11
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx
COPY --chown=${USERNAME}:root files/php-opt.ini /home/${USERNAME}/oss-performance/conf/php.ini
USER ${USERNAME}
