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
PERF_PMUS="cycles,icache_64b.iftag_stall"

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

function get_perf_data() {
  echo 

  start_client_for_perf_data

  echo "--------------------------------------------------"
  echo "`date`:Collect perf data for ${PERF_DATA_COLLECTION_TIME} seconds process ${PROCESS_ID}"
  echo "`date`:perf stat -e ${PERF_PMUS}"
  echo "--------------------------------------------------"
  perf stat -o ${PERF_DATA_FILE} -e ${PERF_PMUS} -p $PROCESS_ID -a sleep ${PERF_DATA_COLLECTION_TIME}
  echo 
}

function get_perf_metric() {
  echo
  echo "--------------------------------------------------"
  echo "`date`:Calculate the final metric"
  echo "--------------------------------------------------"
  cat $PERF_DATA_FILE
  #a=icache_64b.iftag_stall
  #b=cycles
  #metric_ITLB_Misses(%) = 100*(a/d)

  cycles=`grep cycles $PERF_DATA_FILE |cut -d 'c' -f1 | tr -d '[:space:][,]'`
  iftag_stall=`grep icache_64b.iftag_stall $PERF_DATA_FILE | cut -d 'i' -f1 | tr -d '[:space:][,]'`
  echo "Cycles=${cycles}"
  echo "Stalls=${iftag_stall}"
  metric_ITLB_MISSES=`echo "100*(${iftag_stall}/${cycles})"| bc -l`
  #metric_ITLB_MISSES=`bc -l < echo "scale=2; 100*(${iftag_stall}/${cycles})"`
  echo "metric_ITLB_Misses(%)=${metric_ITLB_MISSES}"
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

#start_application

# This is optional
#app_specific_phases #This includes warmup phase for Ghost and measurement phass.

# Get perf data
#get_perf_data

# Reset the application state
cleanup

# Calculate the perf metric
get_perf_metric

exit



