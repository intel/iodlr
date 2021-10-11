ARG baseimage=wp_base
FROM $baseimage

LABEL authors="nitin.tekchandani@intel.com,lin.a.yang@intel.com,uttam.c.pawar@intel.com"

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
