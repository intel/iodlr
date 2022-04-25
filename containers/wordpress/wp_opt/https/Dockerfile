ARG baseimage=wp_http_opt_with_https
FROM $baseimage

LABEL authors="nitin.tekchandani@intel.com,lin.a.yang@intel.com,uttam.c.pawar@intel.com"

ARG IPP_CRYPTO_TAG=ippcp_2021.3
ARG QAT_ENGINE_TAG=v0.6.1
ARG ASYNCH_NGINX_TAG=v0.4.3

# Bolt with https fdata
WORKDIR /home/${USERNAME}/oss-performance
COPY files/perf.fdata /home/${USERNAME}/oss-performance
RUN rm ./php-fpm.bolt
RUN ./llvm-bolt ./php-fpm -o ./php-fpm.bolt -data=perf.fdata -reorder-blocks=cache+ -reorder-functions=hfsort+ -split-functions=3 -split-all-cold -split-eh -dyno-stats

USER root

RUN apt-get update && \
    apt-get install -y libtool

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

# Build/Install QAT engine 
WORKDIR /home/${USERNAME}/temp
RUN git clone  https://github.com/intel/QAT_Engine.git qat_engine && \
    cd qat_engine && \
    git checkout $QAT_ENGINE_TAG && \
    ./autogen.sh && \
    ./configure \
        --enable-multibuff_offload \
        --with-multibuff_install_dir=/home/${USERNAME}/crypto_mb \
        --with-openssl_install_dir=/home/${USERNAME}/openssl_install && \
    make && \
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
