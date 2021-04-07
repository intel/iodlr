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
FROM ubuntu:20.04
LABEL authors="nitin.tekchandani@intel.com,lin.a.yang@intel.com,uttam.c.pawar@intel.com"

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
    libsqlite3-dev \
    gcc-7 \
    g++-7 && \
    rm -rf /var/lib/apt/lists/*

# Install php, php-fpm, php-mysql
RUN add-apt-repository -y ppa:ondrej/php && \
    apt-get update && \
    apt-get install -y \
    php7.4 php7.4-fpm php7.4-mysql \
    php7.4-gd php7.4-mbstring php7.4-xml

# Install nginx, mariadb
RUN apt-get update && apt-get install -y \
    nginx \
    mariadb-server \
 && rm -rf /var/lib/apt/lists/*

# Create new Linux account
RUN useradd -rm -d /home/${USERNAME} -s /bin/bash -g root -G sudo -u 1001 ${USERNAME} && \
    echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" | tee -a /etc/sudoers

# Switch to ${USERNAME}
USER ${USERNAME}
WORKDIR /home/${USERNAME}

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

# Clone and install oss-performance (commit_id: 138c015)
RUN git clone https://github.com/intel/Updates-for-OSS-Performance oss-performance && \
    cd oss-performance && \
    git checkout 138c015
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

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD [ "bash" ]
