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
ARG PHP_VER=7.4
ARG wordpressversion


# ----- php container -----
# used for copying built php-fpm and opcache.so
# 
# ----- php-fpm build container -----
FROM php:${PHP_VER}-fpm AS php-fpm

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
RUN docker-php-source extract; \
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


# ----- siege container -----
# 
# build siege
FROM ubuntu:20.04
LABEL authors="ping.zhao@intel.com"
ARG DEBIAN_FRONTEND="noninteractive"
ARG TZ="America/Los_Angeles"
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1
ENV USERNAME="base"

# Build and install siege 2.78
RUN wget http://download.joedog.org/siege/siege-2.78.tar.gz && \
    tar zxf siege-2.78.tar.gz
WORKDIR /home/${USERNAME}/siege-2.78
RUN ./utils/bootstrap && \
    automake --add-missing && \
    ./configure && \
    make -j8 && \
    sudo make uninstall && \
    sudo make install
WORKDIR /home/${USERNAME}
RUN rm -rf /home/${USERNAME}/siege-2.78


# ----- https base container -----
#
# base container for a;
#   WP 4.2/5.6
#   PHP 7.4/8.0
# --------------------------------
FROM ubuntu:20.04
ENV USERNAME="base"

ARG DEBIAN_FRONTEND="noninteractive"
ARG TZ="America/Los_Angeles"
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1

# Install required packages that are not included in ubuntu core image
RUN apt-get update && apt-get install -y \
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
    libsqlite3-dev; \
    rm -rf /var/lib/apt/lists/*

# Instal PHP
RUN add-apt-repository -y ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y \
    php7.4 php7.4-fpm php7.4-mysql \
    php7.4-gd php7.4-mbstring php7.4-xml
# update php-fpm
COPY --from=php-fpm /php-fpm /opt/pkb/git/hhvm-perf/php-fpm
COPY --from=php-fpm /opcache.so /opt/pkb/git/hhvm-perf/opcache.so


# Install mariadb
RUN apt-get install -y \
    mariadb-server \
 && rm -rf /var/lib/apt/lists/*

# Create new Linux account
RUN useradd -rm -d /home/${USERNAME} -s /bin/bash -g root -G sudo -u 1001 ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Switch to ${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}

# Build and install siege 2.78
# intall later

# Clone and install oss-performance (commit_id: 138c015)
RUN git clone https://github.com/intel/Updates-for-OSS-Performance oss-performance && \
    cd oss-performance && \
    git checkout 0026641

# update wordpress version
ARG wordpressversion
WORKDIR /home/${USERNAME}/oss-performance/targets/wordpress
RUN if [ $wordpressversion != 4.2 ] ; then \
        wget https://wordpress.org/wordpress-${wordpressversion}.tar.gz && \
        sed -i "s/4.2.0/${wordpressversion}/g" WordpressTarget.php && \
        mv WordpressTarget_v5.urls WordpressTarget.urls && \
        mv dbdump_v5.sql.gz dbdump.sql.gz && \
        rm wordpress-4.2.0.tar.gz; \
    fi

WORKDIR /home/${USERNAME}/oss-performance
RUN wget https://getcomposer.org/installer -O composer-setup.php && \
    php composer-setup.php && \
    php composer.phar install

# Basic environment tuning
RUN echo "soft nofile 1000000\nhard nofile 1000000" | sudo tee -a /etc/security/limits.conf

# MariaDB Tuning to disable query cache
COPY files/1s-bkm.j2 /home/${USERNAME}
COPY files/2s-bkm.j2 /home/${USERNAME}
RUN sudo cp /home/${USERNAME}/2s-bkm.j2 /etc/mysql/my.cnf


# Create new MariaDB account "wp_bench" and database "wp_bench"
RUN sudo service mysql start && \
    sleep 1 && \
    sudo mysqladmin -u root password "" && \
    sudo mysql -u root -e "CREATE USER 'wp_bench'@'localhost' IDENTIFIED BY 'wp_bench'" && \
    sudo mysql -u root -e "GRANT ALL PRIVILEGES on *.* to 'wp_bench'@'localhost' IDENTIFIED BY 'wp_bench'" && \
    sudo mysql -u root -e "CREATE DATABASE wp_bench" && \
    sudo mysql -u root -e "FLUSH PRIVILEGES" && \
    sudo service mysql stop

WORKDIR /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=${USERNAME}:root files/quickrun.sh /home/${USERNAME}/oss-performance
RUN chmod +x /home/${USERNAME}/oss-performance/quickrun.sh


# install https modules
#

ENV OPENSSL_TAG=OpenSSL_1_1_1f
ENV NGINX_ARCHIVE_NAME=release-1.18.0
ENV SIEGE_ARCHIVE_NAME='siege-4.0.9'

USER root

RUN apt-get update -y && \
    apt-get remove nginx -y && \
    apt-get install -y \
    libpcre3 \
    libpcre3-dev

# Build/Install openssl
RUN mkdir /home/${USERNAME}/openssl_build
WORKDIR /home/${USERNAME}/openssl_build
RUN git clone https://github.com/openssl/openssl.git && \
    cd openssl && \
    git checkout $OPENSSL_TAG && \
    mkdir -p /home/${USERNAME}/openssl_install/lib/engines-1.1 && \
    ./config --prefix=/home/${USERNAME}/openssl_install \
             -Wl,-rpath=/home/${USERNAME}/openssl && \
     make update && \
     make -j 10 &&  \
     make install
WORKDIR /home/${USERNAME}
RUN rm -rf /home/${USERNAME}/openssl_build


# Comment out RANDFILE entry in /etc/ssl/openssl.cnf
RUN sed -iE 's/RANDFILE\(\s+\=\s\$ENV\:\:HOME\/\.rnd\)/#RANDFILE\1/' /etc/ssl/openssl.cnf

# Create required certificates for https
RUN mkdir -p /home/${USERNAME}/certificates/ssl
WORKDIR /home/${USERNAME}/certificates
RUN openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/C=US/ST=OR/L=IN/O=IN/OU=IN/CN=$(hostname)"
RUN openssl ecparam -genkey -out key.pem -name secp384r1
RUN openssl req -x509 -new -key key.pem -out cert.pem  -subj "/C=US/ST=OR/L=IN/O=IN/OU=IN/CN=$(hostname)"
WORKDIR /home/${USERNAME}/certificates/ssl
RUN chown -R ${USERNAME} /home/${USERNAME}/certificates


# Build/Install AYNCH NGINX, no QAT
WORKDIR /home/${USERNAME}/nginx_build
RUN git clone https://github.com/intel/asynch_mode_nginx.git nginx && \
    cd nginx && \
    git checkout $ASYNCH_NGINX_TAG && \
    ./configure --prefix=/usr/ \
        --with-http_ssl_module \
        '--with-cc-opt=-DNGX_SECURE_MEM \
        -I /home/${USERNAME}/openssl_install/include \
        -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0' \
        '--with-ld-opt=-Wl,-rpath=/home/${USERNAME}/openssl_install/lib \
        -L /home/${USERNAME}/openssl_install/lib' && \
    make -j && \
    make install
WORKDIR /home/${USERNAME}
RUN rm -rf ./nginx_build

# Rebuild siege with ssl, Uninstall Reinstall
WORKDIR /home/${USERNAME}
RUN wget http://download.joedog.org/siege/$SIEGE_ARCHIVE_NAME.tar.gz
RUN tar zxf $SIEGE_ARCHIVE_NAME.tar.gz
WORKDIR /home/${USERNAME}/$SIEGE_ARCHIVE_NAME
RUN ./configure --with-ssl=/usr/bin/openssl && \
    make -j8 && \
    sudo make uninstall && \
    sudo make install
WORKDIR /home/${USERNAME}
RUN rm -rf ./$SIEGE_ARCHIVE_NAME

WORKDIR /home/${USERNAME}/oss-performance

# Modify WordPressTarget urls for https
RUN sed -i 's/http/https/' /home/${USERNAME}/oss-performance/targets/wordpress/WordpressTarget.urls

# Temporary fix
RUN sed -i ':currentline;N;$!bcurrentline;s/invariant.*);//g' /home/${USERNAME}/oss-performance/targets/wordpress/WordpressTarget.php

# Patch https into oss-performance
COPY --chown=${USERNAME}:root files/https_oss_performance.patch /home/${USERNAME}/oss-performance
COPY --chown=${USERNAME}:root files/update_nginx_workers.sh /usr/local/bin/update_nginx_workers.sh
RUN git apply https_oss_performance.patch

RUN sed -r --expression='s/(exec "\$\@")/\/usr\/local\/bin\/update_nginx_workers\.sh\n\1/g' -i /usr/local/bin/entrypoint.sh

COPY --chown=${USERNAME}:root files/ssl-params.conf /home/${USERNAME}/certificates/ssl
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx

USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD [ "bash" ]
