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

COUNT=${COUNT:-6}
IMAGE_NAME=${IMAGE_NAME:-"wp_base_http"}
NUMA_PINNING=${NUMA_PINNING:-0}

while test $# -gt 0; do
    case "$1" in
    -h | --help)
        echo "run.sh - run workload and calculate total TPS"
        echo " "
        echo "run.sh [options]"
        echo " "
        echo "options:"
        echo "-h, --help                 show brief help"
        echo "--image <image_name>       specify a container image to use"
        echo "--count <num>              specify the number of container instances to run"
        echo "--numa-pinning             run container with NUMA pinning"
        exit 0
        ;;
    --image)
        shift
        if test $# -gt 0; then
            export IMAGE_NAME=$1
        else
            echo "no contain image specified"
            exit 1
        fi
        shift
        ;;
    --count)
        shift
        if test $# -gt 0; then
            export COUNT=$1
        else
            echo "no running count specified"
            exit 1
        fi
        shift
        ;;
    --numa-pinning)
        export NUMA_PINNING=1
        shift
        ;;
    *)
        break
        ;;
    esac
done

get_cpu_pinning() {
    sockets_num=$(lscpu | grep "Socket(s):" | sed "s/.* //g")

    for cpu in $(ls -d /sys/devices/system/cpu/cpu[0-9]* | sort -t u -k 3 -n); do
        socket_id=$(cat $cpu/topology/physical_package_id)
        tmp_name=cpusets_socket${socket_id}
        declare ${tmp_name}+=$(cat $cpu/topology/thread_siblings_list)" "
    done

    cpu_pinning_s=()
    count_per_socket=$((COUNT / sockets_num))

    for ((socket_id = 0; socket_id < ${sockets_num}; socket_id++)); do
        tmp_name=cpusets_socket${socket_id}
        all_cpus=($(echo ${!tmp_name} | tr ' ' '\n' | cat -n | sort -uk2 | sort -n | cut -f2- | tr '\n' ' '))
        if [[ ${socket_id} -eq $((${sockets_num} - 1)) ]]; then
            count_per_socket=$(($count_per_socket + $COUNT % $sockets_num))
        fi
        cpu_per_instance=$((${#all_cpus[@]} / $count_per_socket))
        start=0
        for ((i = 1; i <= $count_per_socket; i++)); do
            if [[ ${i} -eq $count_per_socket ]]; then
                array=("${all_cpus[@]:${start}}")
            else
                array=("${all_cpus[@]:${start}:${cpu_per_instance}}")
            fi
            start=$((start + cpu_per_instance))
            cpuset_cpus_s=$(printf ",%s" "${array[@]}")
            cpuset_cpus_s=${cpuset_cpus_s:1}

            docker_run_s="--cpuset-cpus="${cpuset_cpus_s}" --cpuset-mems="${socket_id}
            cpu_pinning_s+=("$docker_run_s")
        done
    done
}

# Calculate the worker number of each instance. Total workers number equals to 1.5X core num on this system.
core_count=$(nproc)
worker_num=$(echo "${core_count} * 1.5 / ${COUNT} " | bc -l)
worker_num=${worker_num%.*}

# Create temp directory for container output
tmp_dir=$(mktemp -d -t run-XXXXXXXXXX)
echo "-------------------------------------------------------------"
echo "Creating temporary directory ${tmp_dir} for logfile."
echo ""

# Launch containers
all_containers=()
if [[ ${NUMA_PINNING} -eq 0 ]]; then
    echo "-------------------------------------------------------------"
    echo "Running ${COUNT} ${IMAGE_NAME} instance(s)."
    echo ""
    for ((i = 0; i < ${COUNT}; i++)); do
        container_id=$(sudo docker run -d --rm -ti --privileged ${IMAGE_NAME} bash -c "./quickrun.sh \"--php-fcgi-children ${worker_num}\"")
        all_containers[$i]=$(sudo docker ps -q -f id=${container_id})
    done
else
    echo "-------------------------------------------------------------"
    echo "Running ${COUNT} ${IMAGE_NAME} instance(s) with NUMA pinning."
    echo ""
    get_cpu_pinning
    for ((i = 0; i < ${COUNT}; i++)); do
        container_id=$(sudo docker run -d --rm -ti --privileged ${cpu_pinning_s[i]} ${IMAGE_NAME} bash -c "./quickrun.sh \"--php-fcgi-children ${worker_num}\"")
        all_containers[$i]=$(sudo docker ps -q -f id=${container_id})
    done
fi

# Redirect containers output to logfile in temp directory
for container_id in ${all_containers[@]}; do
    sudo docker logs -f ${container_id} >${tmp_dir}/${container_id}.log &
done

# Wait all container to be completed
while true; do
    completed=0
    for container_id in ${all_containers[@]}; do
        if [ "$(sudo docker ps -q -f id=${container_id})" ]; then
            completed=1
            echo "Container ${container_id} = running"
        else
            echo "Container ${container_id} = completed"
        fi
    done

    if [ ${completed} -eq 0 ]; then
        echo "-------------------------------------------------------------"
        echo "All instances are completed."
        break
    fi

    echo ""
    echo "-------------------------------------------------------------"
    echo "Sleep 5s to wait all instances to completed and rechecking..."
    echo ""
    sleep 5
done

# Calculate TPS in total
total_tps=0
for i in $(find ${tmp_dir}/*.log); do
    tps=$(grep RPS $i | awk '{ print $3 }' | sed -e 's/,.*$//')
    tps_string="${tps_string} ${tps}"
    total_tps=$(echo "${total_tps} + ${tps}" | bc -l)
done
echo "-------------------------------------------------------------"
echo "TPS of ${COUNT} instances:${tps_string}"
echo "Total TPS: ${total_tps}"

# Remove temp directory
rm -rf ${tmp_dir}
