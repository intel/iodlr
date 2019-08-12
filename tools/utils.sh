#!/bin/bash

# Copyright (C) 2018 Intel Corporation
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
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES
# OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
# OR OTHER DEALINGS IN THE SOFTWARE.
#
# SPDX-License-Identifier: MIT

bc_scale=10

function return_pmu_value() {
  local pmu="$1"
  local perf_data_file="$2"
  if [ "x${pmu}" != "x" ]; then
    local myresult=`grep "\<${1}\>" $perf_data_file | awk '{print $1}' | tr -d '[:space:][,]'`
    echo "$myresult"
  else
    echo "WARNING: No pmu string specified"
    echo -1
  fi
}

function rebuild_metric_args() {
  for item in ${metric_array[*]}
  do
    if [ "x${SUPPORTED_METRICS}" == "x" ]; then
      SUPPORTED_METRICS="$item"
    else
      SUPPORTED_METRICS="$SUPPORTED_METRICS,$item"
    fi
  done
}


function check_if_pmu_exists() {
  local perf_pmus="$1"
  local perf_data_file="$2"

  local OLDIFS=$IFS
  IFS=","; read -ra PMUS <<< "${perf_pmus}"

  local pmu_not_found=0
  for i in "${PMUS[@]}"; do
    pmu_value=`grep ${i} $perf_data_file |awk '{print $1}'| tr -d '[:space:][,]'`
    if [[ "x${pmu_value}" == "x" ]]; then
      echo "PMU ($i) not found with valid value"
      pmu_not_found=1
    else
      echo "PMU_VALUE: $pmu_value"
    fi
  done
  unset IFS

  if [[ ${pmu_not_found} == 1 ]]; then
    echo "Error: Missing required one or more PMUs ($perf_pmus)"
    echo "Here is the perf output data"
    echo
    cat $perf_data_file
    echo
    echo "Ignoring ...."
    echo -1
  fi
}
