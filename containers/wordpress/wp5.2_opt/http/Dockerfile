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
ARG baseimage=wp_opt
FROM $baseimage
LABEL authors="bun.k.tan@intel.com"

WORKDIR /home/${USERNAME}/oss-performance

# Checkout commit in oss-performance with wordpress 5.2 support
RUN git checkout 0026641

WORKDIR /home/${USERNAME}/oss-performance/targets/wordpress

# Download WP5.2, change the WP target from 4.2 to 5.2, replace WP4.2 database dump with WP5.2, and change URLs list, remove WP4.2
RUN wget https://wordpress.org/wordpress-5.2.tar.gz && \
    sed -i 's/4.2.0/5.2/g' WordpressTarget.php && \
    mv WordpressTarget_v5.urls WordpressTarget.urls && \
    mv dbdump_v5.sql.gz dbdump.sql.gz && \
    rm wordpress-4.2.0.tar.gz

WORKDIR /home/${USERNAME}/oss-performance
