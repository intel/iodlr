#!/bin/bash

#set -x

SUPPORTED_METRICS="itlb_stalls,mpki"

process_id=$$

function usage() {
  echo "usage: $0 [-p app_pid] [-m metric_name] [-t time] [-h]"
  echo "app_id : application process id to profile"
  echo "metric_name : itlb_stalls | mpki, etc."
  echo "time : Time in seconds. Default 10s."
  exit
}

if [ $# -eq 0 ]; then
    usage
fi

while [ "$1" != "" ]; do
  case $1 in
    -p | --processid) shift
      app_process_id=$1
      ;;
    -m | --metricname) shift
      metric_name=$1
      ;;
    -t | --processid) shift
      collect_time=$1
      ;;
    *) usage
      exit 1
  esac
  shift
done

if [ "x${app_process_id}" == "x" ]; then
  echo "ERROR: Please specify the application process id to collect the perf data. Exiting."
  exit
fi

# Check if process is still running"
realpid=`/bin/ps ax|grep ${app_process_id}|grep -v grep | grep -v bash`
if [ "x${realpid}" == "x" ]; then
  echo "ERROR: Application with PID ${app_process_id} is not found"
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

#Individual sets of pmus
#ITLB_STALLS
PERF_PMUS="cycles,icache_64b.iftag_stall"

#L2_demand_code_MPI
#PERF_PMUS="instructions,l2_rqsts.code_rd_miss"

#One big set of pmus
#PERF_PMUS="cycles,icache_64b.iftag_stall,instructions,l2_rqsts.code_rd_miss,l2_rqsts.all_code_rd"

PERF_DATA_FILE="/tmp/process_id_perf_stat.txt"

function collect_perf_data() {
  echo 

  echo "--------------------------------------------------"
  echo "`date`:Collect perf data for ${PERF_DATA_COLLECTION_TIME} seconds process ${app_process_id}"
  echo "`date`:perf stat -e ${PERF_PMUS}"
  echo "--------------------------------------------------"
  perf stat -o ${PERF_DATA_FILE} -e ${PERF_PMUS} -p $app_process_id -a sleep ${PERF_DATA_COLLECTION_TIME}
  echo 
}

function check_if_pmu_exists() {
  local OLDIFS=$IFS
  IFS=","; read -ra PMUS <<< "${PERF_PMUS}"

  local pmu_not_found=0
  for i in "${PMUS[@]}"; do
    pmu_value=`grep ${i} $PERF_DATA_FILE |cut -d 'c' -f1 | tr -d '[:space:][,]'`
    if [[ "x${pmu_value}" == "x" ]]; then
      echo "PMU ($i) not found with valid value"
      pmu_not_found=1
    fi
  done
  IFS=$OLDIFS

  if [[ ${pmu_not_found} == 1 ]]; then
    echo "Error: Missing required one or more PMUs ($PERF_PMUS)"
    echo "Here is the perf output data"
    echo
    cat $PERF_DATA_FILE
    echo
    echo "Aborting ...."
    exit 1
  fi

}

function return_pmu_value() {
  if [ "x${1}" == "x" ]; then
    echo "WARNING: No pmu string specified"
    echo 0
  else
    local myresult=`grep ${1} $PERF_DATA_FILE | awk '{print $1}' | tr -d '[:space:][,]'`
    echo "$myresult"
  fi
}

function get_itlb_stall_metric() {
  echo
  echo "================================================="
  echo "Calculate the final itlb_stall metric"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_ITLB_Misses(%) = 100*(a/b)"
  echo "         where, a=icache_64b.iftag_stall"
  echo "                b=cycles"
  echo "================================================="

  # High level PMU check function
  check_if_pmu_exists

  local a=`return_pmu_value "icache_64b.iftag_stall"`
  local b=`return_pmu_value "cycles"`

  local metric=`echo "scale=3;100*(${a}/${b})"| bc -l`
  echo "metric_ITLB_Misses(%)=${metric}"
  echo
}

function get_l2_demand_code_MPI_metric() {
  echo
  echo "================================================="
  echo "Calculate the final l2_demand_code MPI metric"
  echo "--------------------------------------------------"
  #b=inst_retired.any
  echo "FORMULA: metric_L2_demand_code_MPI = (a/b)"
  echo "         where, a=l2_rqsts.code_rd_miss"
  echo "                b=instructions"
  echo "================================================="

  # High level PMU check function
  check_if_pmu_exists

  local a=`return_pmu_value "l2_rqsts.code_rd_miss"`
  local b=`return_pmu_value "instructions"`

  local metric=`echo "scale=3;(${a}/${b})"| bc -l`
  echo "metric_L2_demand_code_MPI=${metric}"
  echo
}

function get_l1_code_read_MPI_metric() {
  echo
  echo "================================================="
  echo "Calculate the final l1_code_read_miss_per_instr"
  echo "--------------------------------------------------"
  echo "FORMULA: metric_L1_code_read_MPI = (a/b)"
  echo "         where, a=l2_rqsts.all_code_rd"
  echo "                b=instructions"
  echo "================================================="

  # High level PMU check function
  check_if_pmu_exists

  local a=`return_pmu_value "l2_rqsts.all_code_rd"`
  local b=`return_pmu_value "instructions"`

  local metric=`echo "scale=3;(${a}/${b})"| bc -l`
  echo "metric_L1_code_read_MPI=${metric}"
  echo
}

function display_perf_data() 
{
  echo
  echo "Here is the perf output data"
  echo
  cat $PERF_DATA_FILE
  echo
}

function check_if_metric_supported() {
  local OLDIFS=$IFS
  IFS=","; read -ra METRICS <<< "${SUPPORTED_METRICS}"

  local metric_not_found=0
  for i in "${METRICS[@]}"; do
    if [ "${i}" != "${metric_name}" ]; then
      metric_not_found=1
    else
      metric_not_found=0
      break
    fi
  done
  IFS=$OLDIFS
  if [[ ${metric_not_found} == 1 ]]; then
    echo "Error: ${metric_name} is not supported. See supported metric."
    echo
    echo "--> $SUPPORTED_METRICS"
    echo
    echo
    echo "Aborting ...."
    exit 1
  fi
  echo "Metric ${metric_name} is supported"
}

# Check if metric asked is supported
check_if_metric_supported

# Get perf data
collect_perf_data

# Calculate the perf metric, we can add more as needed
display_perf_data

if [ "${metric_name}" == "itlb_stalls" ]; then
  get_itlb_stall_metric
fi

#get_l2_demand_code_MPI_metric
#get_l1_code_read_MPI_metric

exit

