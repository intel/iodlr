ARG baseimage
ARG PHP_VER
ARG INSTALL_DIR="/pkg_install"

ARG IPP_CRYPTO_TAG=ippcp_2021.3
ARG QAT_ENGINE_TAG=v0.6.5
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
RUN docker-php-source extract; \
  patch -p1 < 0001-BOLT-PHP${PHP_VER}-GCC-option.patch; \
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
    pkg-config \
    nasm



WORKDIR /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx
COPY --from=bolter --chown=${USERNAME}:root /opt/php-fpm.bolt /home/${USERNAME}/oss-performance/php-fpm
COPY --from=bolter --chown=${USERNAME}:root /opt/opcache.so /home/${USERNAME}/oss-performance/



ARG IPP_CRYPTO_TAG
ARG QAT_ENGINE_TAG
ARG ASYNCH_NGINX_TAG
ARG IPSEC_MB_TAG

ARG iodlrlp=1
ARG query=1

# Optimization: Set environment variable to have zend use large pages
ENV USE_ZEND_ALLOC_HUGE_PAGES=1

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


WORKDIR /home/${USERNAME}/
RUN wget http://archive.ubuntu.com/ubuntu/pool/universe/n/nasm/nasm_2.15.05-1_amd64.deb ; \
    sudo dpkg -i nasm_2.15.05-1_amd64.deb ;\
    wget https://www.openssl.org/source/openssl-1.1.1k.tar.gz ;\
    tar xf openssl-1.1.1k.tar.gz; \
    cd openssl-1.1.1k; \
    ./config --prefix=/opt/openssl/1.1.1k --openssldir=/opt/openssl/1.1.1k; \
    make -j ;\
    sudo make install

ENV PATH=/opt/openssl/1.1.1k/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/openssl/1.1.1k/lib:/opt/crypto_mb/lib:/opt/ipsec-mb/0.55/lib

# Build/Install IPP cyrypto library for the multi-buffer support
WORKDIR /home/${USERNAME}/
RUN git clone --depth 1 -b $IPP_CRYPTO_TAG https://github.com/intel/ipp-crypto.git && \
    export OPENSSL_ROOT_DIR=/opt/openssl/1.1.1k/ && \
    cd ipp-crypto && \
    cd sources/ippcp/crypto_mb && \
    cmake . -Bbuild -DCMAKE_INSTALL_PREFIX=/opt/crypto_mb && \
    cd build && \
    make -j && \
    sudo make install

# Build/install IPSec_MB library
RUN sudo rm -rf ipsec intel-ipsec-mb && \
    mkdir ipsec && \
    git clone --depth 1 -b $IPSEC_MB_TAG https://github.com/intel/intel-ipsec-mb.git && \
    cd intel-ipsec-mb/ && \
    make -j SAFE_DATA=y SAFE_PARAM=y SAFE_LOOKUP=y && \
    sudo make install NOLDCONFIG=y PREFIX=/opt/ipsec-mb/0.55

# Build/Install QAT engine 
WORKDIR /home/${USERNAME}/
ARG HOME="/home/base"
RUN git clone --depth 1 -b $QAT_ENGINE_TAG https://github.com/intel/QAT_Engine.git qat_engine && \
    cd qat_engine && \
    ./autogen.sh && \
    LDFLAGS="-L/opt/ipsec-mb/0.55/lib -L/opt/crypto_mb/lib" CPPFLAGS="-I/opt/ipsec-mb/0.55/include -I/opt/crypto_mb/include" \
    ./configure --enable-qat_sw --prefix=/opt/openssl/1.1.1k --with-openssl_install_dir=/opt/openssl/1.1.1k --with-openssl_dir=$HOME/openssl-1.1.1k && \
    PERL5LIB=$HOME/openssl-1.1.1k make -j && \
    sudo PERL5LIB=$HOME/openssl-1.1.1k make install

ARG ASYNCH_NGINX_TAG
# Build/Install AYNCH NGINX, with QAT
RUN mkdir /home/${USERNAME}/nginx_build && \
    cd /home/${USERNAME}/nginx_build && \
    git clone --depth 1 -b $ASYNCH_NGINX_TAG https://github.com/intel/asynch_mode_nginx.git nginx && \
    cd nginx && \
    ./configure --prefix=/usr/ \
        --with-http_ssl_module --add-dynamic-module=modules/nginx_qat_module \
        --with-cc-opt="-DNGX_SECURE_MEM \
        -I /opt/openssl/1.1.1k/include \
        -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0" \
        --with-ld-opt="-Wl,-rpath=/opt/openssl/1.1.1k/lib \
        -L /opt/openssl/1.1.1k/lib" && \
    make -j && \
    sudo make install && \
    rm -rf /home/${USERNAME}/nginx_build

RUN sudo cp /opt/ipsec-mb/0.55/lib/*.* /usr/lib/
RUN sudo cp /opt/crypto_mb/lib/libcrypto_mb.so.11.1 /usr/lib/libcrypto_mb.so.11
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx
COPY --chown=${USERNAME}:root files/php-opt.ini /home/${USERNAME}/oss-performance/conf/php.ini

WORKDIR /home/${USERNAME}/oss-performance
USER ${USERNAME}
