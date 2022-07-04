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
ARG PHP_VER
ARG INSTALL_DIR="/pkg_install"
ARG OPENSSL_TAG=OpenSSL_1_1_1f
ARG SIEGE_VERSION='siege-2.78'
ARG ASYNCH_NGINX_TAG='v0.4.7'


# ----- php container -----
# used for copying built php-fpm and opcache.so
# 
# ----- php-fpm build container -----
FROM php:${PHP_VER}-fpm AS php-fpm

ENV TZ=America/Los_Angeles
ENV DEBIAN_FRONTEND noninteractive
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime ;\
 echo $TZ > /etc/timezone
RUN docker-php-ext-configure pdo_mysql && \
    docker-php-ext-configure mysqli && \
    docker-php-ext-install -j$(nproc)  mysqli pdo_mysql; \
    cp /usr/local/sbin/php-fpm /php-fpm; \
    cp /usr/local/lib/php/extensions/*/*.so /;

# ----- The container for building the components-----
# build siege, openssl, async Nginx ...
# to copy the binary to worker container
# ----------------------------------------------------
FROM ubuntu:20.04 AS dep-components
ARG DEBIAN_FRONTEND="noninteractive"
ARG TZ="America/Los_Angeles"
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

ENV USERNAME="base"
ARG INSTALL_DIR

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
    libonig5

RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-10 10 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-10 10

ARG OPENSSL_TAG
ARG SIEGE_VERSION

# Build/Install openssl
RUN mkdir -p /home/${USERNAME}/openssl_build
WORKDIR /home/${USERNAME}/openssl_build
RUN git clone --depth 1 -b $OPENSSL_TAG https://github.com/openssl/openssl.git && \
    cd openssl && \
    mkdir -p /home/${USERNAME}/openssl_install/lib/engines-1.1 && \
    ./config --prefix=/home/${USERNAME}/openssl_install \
             -Wl,-rpath=/home/${USERNAME}/openssl && \
    make update && \
    make -j &&  \
    mkdir -p $INSTALL_DIR ; \
    make install DESTDIR=$INSTALL_DIR && \
    rm -rf /home/${USERNAME}/openssl_build


# build siege with ssl, Uninstall & Reinstall
# Build and install siege 2.78
RUN cd /home/${USERNAME}; \
    wget http://download.joedog.org/siege/${SIEGE_VERSION}.tar.gz && \
    tar zxf ${SIEGE_VERSION}.tar.gz
WORKDIR /home/${USERNAME}/${SIEGE_VERSION}
RUN ./utils/bootstrap && \
    automake --add-missing && \
    ./configure --with-ssl=/usr/bin/openssl  && \
    make -j && \
    sudo make uninstall && \
    mkdir -p $INSTALL_DIR/usr/local/etc && \
    sudo make install DESTDIR=$INSTALL_DIR ;

ARG ASYNCH_NGINX_TAG
# Build/Install AYNCH NGINX, no QAT
WORKDIR /home/${USERNAME}/nginx_build
RUN git clone --depth 1 -b $ASYNCH_NGINX_TAG https://github.com/intel/asynch_mode_nginx.git nginx && \
    cd nginx && \
    ./configure --prefix=/usr/ \
        --with-http_ssl_module \
        '--with-cc-opt=-DNGX_SECURE_MEM \
        -I /home/${USERNAME}/openssl_install/include \
        -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0' \
        '--with-ld-opt=-Wl,-rpath=/home/${USERNAME}/openssl_install/lib \
        -L /home/${USERNAME}/openssl_install/lib' && \
    make -j && \
    make install DESTDIR=$INSTALL_DIR && \
    rm -rf /home/${USERNAME}/nginx_build

# ----- https base container -----
#
# base container for a;
#   WP 4.2/5.6
#   PHP 7.4/8.0
# --------------------------------
FROM ubuntu:20.04
LABEL authors="ping.zhao@intel.com, yuhan.yang@intel.com"
ENV USERNAME="base"

ARG INSTALL_DIR
ARG DEBIAN_FRONTEND="noninteractive"
ARG TZ="America/Los_Angeles"
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Install required packages that are not included in ubuntu core image and mariadb
RUN apt-get update && apt-get install -y \
    software-properties-common \
    apt-transport-https \
    vim \
    git \
    wget \
    python3-pip \
    sudo \
    linux-tools-common \
    libssl-dev \
    php-mysql \
    php \
    libonig5 \
    libpcre3 \
    libpcre3-dev \    
    mariadb-server && \
    rm -rf /var/lib/apt/lists/*

# Create a new Linux account
RUN useradd -rm -d /home/${USERNAME} -s /bin/bash -g root -G sudo -u 1001 ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Switch to ${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Clone and install oss-performance
# If WP not 4.2, download and update with wordpressversion, replace WP4.2 database dump with WP5.2, and change URLs list, remove WP4.2
ARG wordpressversion
RUN git clone --depth 1 -b v1.3 https://github.com/intel/Updates-for-OSS-Performance oss-performance && \
    cd oss-performance && \
    cd /home/${USERNAME}/oss-performance/targets/wordpress && \
    if [ $wordpressversion != 4.2 ] ; then \
        wget https://wordpress.org/wordpress-${wordpressversion}.tar.gz && \
        sed -i "s/4.2.0/${wordpressversion}/g" WordpressTarget.php && \
        mv WordpressTarget_v5.urls WordpressTarget.urls && \
        mv dbdump_v5.sql.gz dbdump.sql.gz && \
        rm wordpress-4.2.0.tar.gz; \
    fi

WORKDIR /home/${USERNAME}/oss-performance
RUN wget https://getcomposer.org/installer -O composer-setup.php && \
    php composer-setup.php && \
    php composer.phar install && \
    # Basic environment tuning
    echo "soft nofile 1000000\nhard nofile 1000000" | sudo tee -a /etc/security/limits.conf

# MariaDB Tuning to disable query cache
COPY files/1s-bkm.j2 /home/${USERNAME}
COPY files/2s-bkm.j2 /home/${USERNAME}
RUN sudo cp /home/${USERNAME}/2s-bkm.j2 /etc/mysql/my.cnf && \
    # Create new MariaDB account "wp_bench" and database "wp_bench"
    sudo service mysql start && \
    sleep 1 && \
    sudo mysqladmin -u root password "" && \
    sudo mysql -u root -e "CREATE USER 'wp_bench'@'localhost' IDENTIFIED BY 'wp_bench'" && \
    sudo mysql -u root -e "GRANT ALL PRIVILEGES on *.* to 'wp_bench'@'localhost' IDENTIFIED BY 'wp_bench'" && \
    sudo mysql -u root -e "CREATE DATABASE wp_bench" && \
    sudo mysql -u root -e "FLUSH PRIVILEGES" && \
    sudo service mysql stop

# https modules
USER root

# Binary copy openssl, siege, AYNCH NGINX no QAT, 
COPY  --from=dep-components --chown=${USERNAME}:root $INSTALL_DIR /

# Comment out RANDFILE entry in /etc/ssl/openssl.cnf
# Create required certificates for https
WORKDIR /home/${USERNAME}/certificates
RUN sed -iE 's/RANDFILE\(\s+\=\s\$ENV\:\:HOME\/\.rnd\)/#RANDFILE\1/' /etc/ssl/openssl.cnf && \
    mkdir -p /home/${USERNAME}/certificates/ssl && \
    openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:4096 -keyout server.key -out server.crt -subj "/C=US/ST=OR/L=IN/O=IN/OU=IN/CN=$(hostname)" && \
    openssl ecparam -genkey -out key.pem -name secp384r1 && \
    openssl req -x509 -new -key key.pem -out cert.pem  -subj "/C=US/ST=OR/L=IN/O=IN/OU=IN/CN=$(hostname)" && \ 
    chown -R ${USERNAME} /home/${USERNAME}/certificates


WORKDIR /home/${USERNAME}/oss-performance
# Modify WordPressTarget urls for https and temporary fix
RUN sed -i 's/http/https/' /home/${USERNAME}/oss-performance/targets/wordpress/WordpressTarget.urls && \
    sed -i ':currentline;N;$!bcurrentline;s/invariant.*);//g' /home/${USERNAME}/oss-performance/targets/wordpress/WordpressTarget.php

# Patch https into oss-performance
COPY --chown=${USERNAME}:root files/https_oss_performance.patch /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/update_nginx_workers.sh /usr/local/bin/update_nginx_workers.sh
RUN git apply https_oss_performance.patch

COPY --chown=${USERNAME}:root files/ssl-params.conf /home/${USERNAME}/certificates/ssl
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx
COPY --chown=${USERNAME}:root files/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -r --expression='s/(exec "\$\@")/\/usr\/local\/bin\/update_nginx_workers\.sh\n\1/g' -i /usr/local/bin/entrypoint.sh

USER ${USERNAME}
COPY --from=php-fpm --chown=${USERNAME}:root /php-fpm /home/${USERNAME}/oss-performance
COPY --from=php-fpm --chown=${USERNAME}:root /opcache.so /home/${USERNAME}/oss-performance
COPY --from=php-fpm --chown=${USERNAME}:root /pdo_mysql.so /home/${USERNAME}/oss-performance
COPY --from=php-fpm --chown=${USERNAME}:root /mysqli.so /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/quickrun.sh /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/php-base.ini /home/${USERNAME}/oss-performance/conf/php.ini
RUN chmod +x /home/${USERNAME}/oss-performance/quickrun.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD [ "bash" ]
