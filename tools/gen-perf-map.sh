#!/usr/bin/bash

if [ "$#" -lt 4 ]; then
    echo "Usage: $0 -s|-b PATH BASEADDRESS TID"
    exit 1
fi

if [ "$1" = "-s" ]; then
    NM_ARGS="-DSC"
elif [ "$1" = "-b" ]; then
    NM_ARGS="-aSC"
else
    echo "Pass either -s (shared lib) or -b (binary)"
    exit 1
fi

nm $NM_ARGS $2 | grep " [TtVWu] " | awk '{$3=""; print$0}' > nm-output.txt

$( dirname -- "$0"; )/maps_file.py $3

cat ./tmp.map >> "/tmp/perf-$4.map"

rm ./nm-output.txt ./tmp.map
echo "Generated /tmp/perf-$4.map"
