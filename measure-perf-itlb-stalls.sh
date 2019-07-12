#!/bin/bash

#set -x
DEFAULT_NODE_PATH=/usr/bin/
LTS11_NODE_PATH=/home/upawar/node-v11.13.0-linux-x64/bin
MASTER_NODE_PATH=/home/upawar/projects/node/out/Release

NODE_UT=$DEFAULT_NODE_PATH
NODE_UT=$MASTER_NODE_PATH
NODE_UT=$LTS11_NODE_PATH

export PATH=$NODE_UT:$PATH

which node
node -v
APP_NAME="ghost_app"

NCLUSTERS=1 #1, 2, 4, 8
NPROCS=1    #1, 4, 8, 14

PERF_DATA_COLLECTION_TIME=10 #perf collection time in seconds

#Individual sets of pmus
#ITLB_STALLS
PERF_PMUS="cycles,icache_64b.iftag_stall"

#L2_demand_code_MPI
PERF_PMUS="instructions,l2_rqsts.code_rd_miss"

#One big set of pmus
PERF_PMUS="cycles,icache_64b.iftag_stall,instructions,l2_rqsts.code_rd_miss,l2_rqsts.all_code_rd"

PROCESS_ID=0 #Initialization
PERF_DATA_FILE="perf_stat.txt"

# Start the ghost.js application ....
function start_application() {
  echo
  echo "--------------------------------------------------"
  echo "`date`: Starting the Ghost.js server"
  echo "--------------------------------------------------"

  NODE_ENV=production pm2 start --name ${APP_NAME} -i ${NPROCS} index.js 

  sleep 5
  echo "--------------------------------------------------"
  echo "`date`: Get node application process id"
  PROCESS_ID=`pm2 prettylist|grep -v _pid | grep pid|cut -d':' -f2|cut -d ',' -f1`
  echo "process id is ${PROCESS_ID}"
  echo 
}

function warm_up_phase() {
  echo 
  echo "--------------------------------------------------"
  echo "`date`: Starting ab client to warm up the application"
  echo "Warmup:----------------------------------------------"
  ab -n 10000 -c 50  http://127.0.0.1:8013/
  echo 
  sleep 5
}

function get_rps_phase() {
  echo 
  echo "Get RPS:---------------------------------------------"
  ab -n 20000 -c 50  http://127.0.0.1:8013/
  echo 
}

function start_client_for_perf_data() {
  echo 
  echo "--------------------------------------------------"
  echo "`date`: Starting ab client to collect perf data"
  echo "--------------------------------------------------"
  ab -n 100000 -c 50  http://127.0.0.1:8013/ &
  sleep 15
  echo 
}

function collect_perf_data() {
  echo 

  start_client_for_perf_data

  echo "--------------------------------------------------"
  echo "`date`:Collect perf data for ${PERF_DATA_COLLECTION_TIME} seconds process ${PROCESS_ID}"
  echo "`date`:perf stat -e ${PERF_PMUS}"
  echo "--------------------------------------------------"
  perf stat -o ${PERF_DATA_FILE} -e ${PERF_PMUS} -p $PROCESS_ID -a sleep ${PERF_DATA_COLLECTION_TIME}
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

function app_specific_phases() {
  warm_up_phase
  #get_rps_phase
}

function stop_application() {
  echo 
  pm2 stop ${APP_NAME}
  pm2 delete ${APP_NAME}
  echo 
}

function cleanup() {
  stop_application
}

# Reset the application state
cleanup

# Function to start an application
#start_application

# This is optional
#app_specific_phases #This includes warmup phase for Ghost and measurement phass.

# Get perf data
#collect_perf_data

# Reset the application state (stop or kill all processes)
cleanup

# Calculate the perf metric, we can add more as needed
display_perf_data

get_itlb_stall_metric
#get_l2_demand_code_MPI_metric
get_l1_code_read_MPI_metric

exit

