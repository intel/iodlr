#!/bin/bash
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

# Disable kernel ASLR (address space layout randomization)
echo -e "Disable kernel ASLR (address space layout randomization)"
sudo sysctl -w kernel.randomize_va_space=0

# Flush file system buffers
echo -e "Flushing file system buffers"
sudo sync
# Free pagecache, dentries and inodes
echo -e "Free pagecache, dentries and inodes"
sudo sh -c 'echo 3 >/proc/sys/vm/drop_caches'
# Free swap memory
echo -e "Free swap memory"
sudo swapoff -a
sudo swapon -a

# Increase nf_conntrack hashtable size to 512000
echo -e "Increasing nf_conntrack hashtable size to 512000"
NF_CONNTRACK_MAX=/proc/sys/net/netfilter/nf_conntrack_max
if [ -e $NF_CONNTRACK_MAX ]; then
    echo 512000 | sudo tee  $NF_CONNTRACK_MAX
fi

# Set CPU scaling governor to max performance
echo -e "Setting CPU scaling governor to max performance"
if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
    for i in $(seq 0 $(($(nproc)-1))); do
        echo "performance" | sudo tee /sys/devices/system/cpu/cpu"$i"/cpufreq/scaling_governor
    done
fi

# Set tcp socket reuse
echo -e "Setting TCP TIME WAIT"
echo 1 | sudo tee /proc/sys/net/ipv4/tcp_tw_reuse

# Start database daemon
echo -e "Starting database daemon"
sudo service mysql start

exec "$@"
