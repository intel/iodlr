#!/bin/bash

// Copyright (C) 2018 Intel Corporation
//
// Permission is hereby granted, free of charge, to any person obtaining a
// copy of this software and associated documentation files
// (the "Software"), to deal in the Software without restriction,
// including without limitation the rights to use, copy, modify, merge,
// publish, distribute, sublicense, and/or sell copies of the Software,
// and to permit persons to whom the Software is furnished to do so, 
// subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
// THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
// OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
// ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
// OR OTHER DEALINGS IN THE SOFTWARE.
//
// SPDX-License-Identifier: MIT

SCRIPTS_DIR=`dirname $0`

process_id=$$

metric_array=(itlb_stalls)
metric_entries=1

pmu_array=(cycles instructions)
pmu_entries=2

metric_name="itlb_stalls"
input_metrics=()
input_metric_idx=0

verbose_mode=0
debug_mode=0
collect_time=10
perf_mode="stat"
scale=10
profile_mode="one"
PERF_PMUS=""

#####################################################################
#
#####################################################################
function print_metric_array() {
  if [ $debug_mode -eq 1 ]; then
    for item in ${metric_array[*]}
    do
      printf ".....%s\n" $item
    done
  fi
}

function usage() {
  echo "usage: $0 [-p app_pid | -a] [-m metric1,metric2,...] [-t time] [-r] [-v] [-h]"
  echo "-a : Profile whole system"
  echo "-p app_id : application process id to profile"
  echo "-m metrics : Use comma separator to specify one or many of the"
  echo "             following metrics."
  debug_mode=1
  print_metric_array
  debug_mode=0
  echo "     Default metric is itlb_stalls."
  echo "-t time : time in seconds. Default 10s."
  echo "-r : Perf runs in record mode. Default is perf stat mode"
  echo "-v : Verbose mode"
  echo "-d : Debug mode"
  echo "-h : Help message."
  echo "examples:"
  echo "  1) Single metric with verbose output:"
  echo "    $ measure-perf-metric.sh -p 2345 -t 30 -m itlb_stalls -v"
  echo
  echo "  2) Multiple metrics:"
  echo "    $ measure-perf-metric.sh -p 2345 -t 30 -m itlb_stalls,itlb_mpki"
  echo
  echo "  3) Whole system collection:"
  echo "    $ measure-perf-metric.sh -a -t 30 -m itlb_stalls"
  exit
}

# Build supported METRIC array ----
function add_to_metric_array() {
  local found=0

  #Check if the metric is already in the array
  for item in ${metric_array[*]}
  do
    if [ "$item" == "$1" ]; then
      found=1
      break
    fi
  done

  if [ $found -eq 0 ]; then
    metric_array[metric_entries]=$1
    metric_entries=`expr $metric_entries + 1`
  fi
}

function init_metric_array() {
  for i in `ls $SCRIPTS_DIR/init_*.sh`
  do
    local metric=`basename $i|cut -d'_' -f2- | cut -d'.' -f1`
    source ${i} > /dev/null 2>&1
    if [ $? != 0 ]; then
      echo "ERROR: couldn't source ${i} "
    else
      add_to_metric_array "$metric"
    fi
  done

  # Debug mode print
  print_metric_array
}

# Build array of supported metrics
init_metric_array

if [ $# -eq 0 ]; then
    usage
fi

while [ "$1" != "" ]; do
  case $1 in
    -a) profile_mode="system"
        app_process_id=""
      ;;
    -p) shift
      app_process_id=$1
      profile_mode="one"
      ;;
    -m) shift
      metric_name=$1
      ;;
    -t) shift
      collect_time=$1
      ;;
    -r) perf_mode="record"
      ;;
    -v) verbose_mode=1
      ;;
    -d) debug_mode=1
      ;;
    *) usage
      exit 1
  esac
  shift
done

if [ "x${app_process_id}" == "x" -a "${profile_mode}" == "one" ]; then
  echo "ERROR: Please specify the application process id or use -a option to profile the whole system. Exiting."
  exit
fi

if [ "x${metric_name}" == "x" ]; then
  echo "WARNING: ITLB_STALLS as a default metric will be derived"
  metric_name="itlb_stalls"
fi

if [ "x${collect_time}" == "x" ]; then
  echo "WARNING: Default perf data collection time is 10 seconds"
  collect_time=10
fi

PERF_DATA_COLLECTION_TIME=$collect_time #perf collection time in seconds
PERF_DATA_FILE="/tmp/measure_${process_id}_perf_stat.txt"

# Build input metric array
function print_input_metric_array() {
  if [ $debug_mode -eq 1 ]; then
    for item in ${input_metrics[*]}
    do
      printf "   %s\n" $item
    done
  fi
}

function add_to_input_metric_array() {
  local found=0

  #Check if the metric is already in the array
  for item in ${input_metrics[*]}
  do
    if [ "$item" == "$1" ]; then
      found=1
      break
    fi
  done

  if [ $found -eq 0 ]; then
    input_metrics[input_metric_idx]=$1
    input_metric_idx=`expr $input_metric_idx + 1`
  fi
}

function add_if_valid_metric() {
  local found=0
  local input_metric="$1"
  for item in ${metric_array[*]}
  do
    if [ "$item" == "$input_metric" ]; then
      found=1
      add_to_input_metric_array "$input_metric"
      break
    fi
  done
  if [ $found -eq 0 ]; then
    echo "Warning: Ignoring invalid metric: $input_metric."
  fi
}

function build_input_metric_array() {

  if [ $debug_mode -eq 1 ]; then
    echo "Before build input metric array"
    echo "Array length: ${#input_metrics[@]}"
    print_input_metric_array
  fi

  local OLDIFS=$IFS
  IFS=","; read -ra local_metric <<< "${metric_name}"

  for i in "${local_metric[@]}"
  do
    add_if_valid_metric "$i"
  done
  IFS=$OLDIFS

  if [ $debug_mode -eq 1 ]; then
    echo "After build input metric array"
    echo "Array length: ${#input_metrics[@]}"
    print_input_metric_array
  fi
}

# PMU array ----
function print_perf_pmu_array() {
  if [ $debug_mode -eq 1 ]; then
    for item in ${pmu_array[*]}
    do
      printf "   %s\n" $item
    done
  fi
}

function add_to_pmu_array() {
  local found=0

  #Check if the metric is already in the array
  for item in ${pmu_array[*]}
  do
    if [ "$item" == "$1" ]; then
      found=1
      break
    fi
  done

  if [ $found -eq 0 ]; then
    pmu_array[pmu_entries]=$1
    pmu_entries=`expr $pmu_entries + 1`
  fi
}

function rebuild_perf_pmu_args() {
  for item in ${pmu_array[*]}
  do
    if [ "x${PERF_PMUS}" == "x" ]; then
      PERF_PMUS="$item"
    else
      PERF_PMUS="$PERF_PMUS,$item"
    fi
  done
}

function init_perf_pmus() {
  for item in ${input_metrics[*]}
  do
    echo "Initializing for metric: $item"

    init_func="init_${item}"
  
    local specific_pmus=`${init_func}`
 
    local OLDIFS=$IFS
    IFS=","; read -ra local_pmus <<< "${specific_pmus}"

    for i in "${local_pmus[@]}"
    do
      add_to_pmu_array "$i"
    done
    IFS=$OLDIFS
  done

  # Debug mode print
  print_perf_pmu_array

  # Rebuild PMU list to pass to perf command
  rebuild_perf_pmu_args
}

function collect_perf_data() {
  echo 

  # Check if process is still running"
  echo "Collect perf data for ${PERF_DATA_COLLECTION_TIME} seconds"
  echo "perf ${perf_mode} -e ${PERF_PMUS}"

  if [ "${profile_mode}" == "system" ]; then
    echo "--------------------------------------------------"
    echo "Profiling whole system"
    echo "--------------------------------------------------"
    perf ${perf_mode} -o ${PERF_DATA_FILE} -e ${PERF_PMUS} -a sleep ${PERF_DATA_COLLECTION_TIME}
  else
    realpid=`/bin/ps ax|grep ${app_process_id}|grep -v grep | grep -v bash`
    if [ "x${realpid}" == "x" ]; then
     echo "ERROR: Application with PID ${app_process_id} is not found"
     exit
    fi
    echo "--------------------------------------------------"
    echo "Profile application with process id: $app_process_id"
    echo "--------------------------------------------------"
    perf ${perf_mode} -o ${PERF_DATA_FILE} -e ${PERF_PMUS} -p $app_process_id sleep ${PERF_DATA_COLLECTION_TIME}
  fi
  echo 
}

function display_perf_data() 
{
  if [ $verbose_mode -eq 1 ]; then
    echo "================================================="
    echo "Here is the perf output data"
    echo "================================================="
    if [ "${perf_mode}"  == "stat" ]; then
     cat $PERF_DATA_FILE
    fi
  fi
  echo
}

# Build valid input metric array
build_input_metric_array
if [ ${#input_metrics[@]} -le 0 ]; then
  echo "Error: No valid input metric provided. Exiting."
  exit
fi

# Check if metric asked is supported
#check_if_metric_supported

# Initialize the PMUS
init_perf_pmus

# Get perf data
collect_perf_data

if [ "${perf_mode}"  == "stat" ]; then
  #Display perf stat data
  display_perf_data

  for item in ${input_metrics[*]}
  do
    echo "Calculating metric for: $item"

    calc_func="calc_${item}"
    ${calc_func} "${PERF_DATA_FILE}"

    echo
  done
else
  echo "Perf report: perf report --sort=dso,comm -i $PERF_DATA_FILE"
  perf report --sort=dso,comm -i $PERF_DATA_FILE
fi

exit

