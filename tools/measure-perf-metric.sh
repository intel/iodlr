#!/bin/bash
#set -x
SCRIPTS_DIR=`dirname $0`

process_id=$$

metric_array=(itlb_stalls)
metric_entries=1

pmu_array=(cycles instructions)
pmu_entries=2

verbose_mode=0
debug_mode=0
collect_time=10
perf_mode="stat"
scale=10
profile_mode="one"
metric_name="itlb_stalls"
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
  echo "usage: $0 [-p app_pid | -a] [-m metric_name] [-t time] [-r] [-v] [-h]"
  echo "-a : Profile whole system"
  echo "-p app_id : application process id to profile"
  echo "-m metric_name : Use one of the following metric"
  debug_mode=1
  print_metric_array
  debug_mode=0
  echo "     Default metric is itlb_stalls."
  echo "-t time : time in seconds. Default 10s."
  echo "-r : Perf runs in record mode. Default is perf stat mode"
  echo "-v : Verbose mode"
  echo "-d : Debug mode"
  echo "-h : Help message."
  exit
}

# METRIC array ----
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
  echo "Initializing for metric: $metric_name"

  init_func="init_${metric_name}"
  
  local specific_pmus=`${init_func}`
 
  local OLDIFS=$IFS
  IFS=","; read -ra local_pmus <<< "${specific_pmus}"

  for i in "${local_pmus[@]}"
  do
    add_to_pmu_array "$i"
  done
  IFS=$OLDIFS

  # Debug mode print
  print_perf_pmu_array

  # Rebuild PMU list to pass to perf command
  rebuild_perf_pmu_args
}

function check_if_metric_supported() {
  local metric_not_found=0
  for item in ${metric_array[*]}
  do
    if [ "${item}" != "${metric_name}" ]; then
      metric_not_found=1
    else
      metric_not_found=0
      break
    fi
  done

  if [[ ${metric_not_found} == 1 ]]; then
    echo "Error: Unsupported metric ${metric_name}. See usage."
    echo
    usage
    echo "Aborting ...."
    exit 1
  fi
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

# Check if metric asked is supported
check_if_metric_supported

# Initialize the PMUS
init_perf_pmus

# Get perf data
collect_perf_data

if [ "${perf_mode}"  == "stat" ]; then
  #Display perf stat data
  display_perf_data

  calc_func="calc_${metric_name}"
  ${calc_func} "${PERF_DATA_FILE}"
else
  echo "Perf report: perf report --sort=dso,comm -i $PERF_DATA_FILE"
  perf report --sort=dso,comm -i $PERF_DATA_FILE
fi

exit

