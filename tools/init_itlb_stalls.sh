#!/bin/bash -x
SCRIPTS_DIR=`dirname $0`

source ${SCRIPTS_DIR}/utils.sh


function init_itlb_stalls() {
  #Comma seperated perf supported counter names. See example below"
  local local_pmu_array=(instructions icache_64b.iftag_stall)
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

function calc_itlb_stalls() {
  local perf_data_file="$1"
  echo
  echo "================================================="
  echo "Final itlb_stalls metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_ITLB_Misses(%) = 100*(a/b)"
  echo "         where, a=icache_64b.iftag_stall"
  echo "                b=cycles"
  echo "================================================="

  local a=`return_pmu_value "icache_64b.iftag_stall" ${perf_data_file}`
  local b=`return_pmu_value "cycles" ${perf_data_file}`

  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: metric_ITLB_Misses can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$bc_scale;100*(${a}/${b})"| bc -l`
    echo "metric_ITLB_Misses(%)=${metric}"
  fi

}
