ARG baseimage=wp_base
FROM $baseimage

LABEL authors="nitin.tekchandani@intel.com,lin.a.yang@intel.com,uttam.c.pawar@intel.com"

USER root

RUN apt-get update -y && \
    apt-get remove nginx -y && \
    apt-get install -y \
    libpcre3 \
    libpcre3-dev


# Build/Install openssl v1_1_1f
RUN mkdir /home/${USERNAME}/temp
WORKDIR /home/${USERNAME}/temp
RUN git clone https://github.com/openssl/openssl.git && \
    cd openssl && \
    git checkout OpenSSL_1_1_1f && \
    mkdir -p /home/${USERNAME}/openssl_install/lib/engines-1.1 && \
    ./config --prefix=/home/${USERNAME}/openssl_install \
             -Wl,-rpath=/home/${USERNAME}/openssl && \
     make update && \
     make -j 10 &&  \
     make install
WORKDIR /home/${USERNAME}
RUN rm -rf /home/${USERNAME}/temp

# Comment out RANDFILE entry in /etc/ssl/openssl.cnf
RUN sed -iE 's/RANDFILE\(\s+\=\s\$ENV\:\:HOME\/\.rnd\)/#RANDFILE\1/' /etc/ssl/openssl.cnf

# Create required certificates for https
RUN mkdir -p /home/${USERNAME}/certificates/ssl
WORKDIR /home/${USERNAME}/certificates
RUN openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -keyout server.key -out server.crt -subj "/C=US/ST=OR/L=IN/O=IN/OU=IN/CN=$(hostname)"
RUN openssl ecparam -genkey -out key.pem -name prime256v1
RUN openssl req -x509 -new -key key.pem -out cert.pem  -subj "/C=US/ST=OR/L=IN/O=IN/OU=IN/CN=$(hostname)"
WORKDIR /home/${USERNAME}/certificates/ssl
RUN openssl dhparam -out dhparam.pem 2048
RUN chown -R ${USERNAME} /home/${USERNAME}/certificates

# NGINX
WORKDIR /home/${USERNAME}/temp
RUN wget http://hg.nginx.org/nginx/archive/release-1.18.0.tar.gz
RUN tar zxf release-1.18.0.tar.gz
RUN cd nginx-release-1.18.0 && \
    ./auto/configure --with-http_ssl_module \
        '--with-cc-opt=-I /home/${USERNAME}/openssl_install/include \
        -Wno-error=deprecated-declarations -Wimplicit-fallthrough=0' \
        '--with-ld-opt=-Wl,-rpath=/home/${USERNAME}/openssl_install/lib \
        -L /home/${USERNAME}/openssl_install/lib' && \
    make -j && \
    make install 

# Rebuild siege with ssl, Uninstall Reinstall
WORKDIR /home/${USERNAME}
RUN wget http://download.joedog.org/siege/siege-4.0.9.tar.gz
RUN tar zxf siege-4.0.9.tar.gz
WORKDIR /home/${USERNAME}/siege-4.0.9
RUN ./configure --with-ssl=/usr/bin/openssl && \
    make -j8 && \
    sudo make uninstall && \
    sudo make install
WORKDIR /home/${USERNAME}
RUN rm -rf ./siege-4.0.9

# Modify WordPressTarget urls for https
RUN sed -i 's/http/https/' /home/${USERNAME}/oss-performance/targets/wordpress/WordpressTarget.urls

# Temporary fix
RUN sed -i ':currentline;N;$!bcurrentline;s/invariant.*);//g' /home/${USERNAME}/oss-performance/targets/wordpress/WordpressTarget.php

USER ${USERNAME}
WORKDIR /home/${USERNAME}/oss-performance

# Patch https into oss-performance
COPY --chown=${USERNAME}:root files/https_oss_performance.patch /home/${USERNAME}/oss-performance
RUN git apply https_oss_performance.patch

COPY --chown=${USERNAME}:root files/ssl-params.conf /home/${USERNAME}/certificates/ssl
COPY --chown=${USERNAME}:root files/nginx.conf.in /home/${USERNAME}/oss-performance/conf/nginx

