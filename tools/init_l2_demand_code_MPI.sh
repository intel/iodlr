#!/bin/bash
SCRIPTS_DIR=`dirname $0`
source ${SCRIPTS_DIR}/utils.sh

function init_l2_demand_code_MPI() {
  local local_pmu_array=(instructions l2_rqsts.all_code_rd)
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

function calc_l2_demand_code_MPI() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final L2_demand_code MPI metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_L2_demand_code_MPI = (a/b)"
  echo "         where, a=l2_rqsts.all_code_rd"
  echo "                b=instructions"
  echo "================================================="

  local a=`return_pmu_value "l2_rqsts.all_code_rd" $perf_data_file `
  local b=`return_pmu_value "instructions" $perf_data_file`
  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_L2_demand_code_MPI can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$scale;(${a}/${b})"| bc -l`
    echo "metric_L2_demand_code_MPI=${metric}"
  fi

  echo
}
