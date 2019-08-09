#!/bin/bash
SCRIPTS_DIR=`dirname $0`
source ${SCRIPTS_DIR}/utils.sh

function init_l1_code_read_MPI() {
  #Comma seperated perf supported counter names. See example below"
  local local_pmu_array=(instructions l2_rqsts.code_rd_miss)
  local local_pmus
  for item in ${local_pmu_array[*]}
  do
    if [ "x${local_pmus}" == "x" ]; then
      local_pmus="$item"
    else
      local_pmus="$local_pmus,$item"
    fi
  done
  echo $local_pmus
}

function calc_l1_code_read_MPI() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final L1_code_read_MPI metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_name = formula for e.g. 100*(a/b)"
  echo "         where, a=l2_rqsts.code_rd_miss"
  echo "                b=instructions"
  echo "================================================="

  local a=`return_pmu_value "l2_rqsts.code_rd_miss" ${perf_data_file}`
  local b=`return_pmu_value "instructions" ${perf_data_file}`

  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_L1_code_read_MPI can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$scale;(${a}/${b})"| bc -l`
    echo "metric_L1_code_read_MPI=${metric}"
  fi
  echo
}

