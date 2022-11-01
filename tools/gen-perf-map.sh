#!/usr/bin/bash

if [ "$#" -lt 3 ]; then
    echo "Usage: $0 LIB BASEADDRESS TID"
    exit 1
fi

nm -DSC $1 | grep " [TVWu] " | awk '{$3=""; print$0}' > nm-output.txt

./maps_file.py $2

cat ./tmp.map >> "/tmp/perf-$3.map"

rm ./nm-output.txt ./tmp.map
echo "Generated /tmp/perf-$3.map"
