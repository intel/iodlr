# RBB/tools

This directory contains set of convenience scripts based on "standard perf" for profile collection and to derive high level metric for further analysis. "perf" in turn uses performance counters in the CPU.

# Current features

* measure-perf-metric.sh is a top level script.
* all metric_* files contain currently supported metrics. From the name you can see the list of supported metrics such as "itlb_stalls, itlb_mpki, l1_code_read_MPI, l2_demand_code_MPI".
* There is only one metric_ file for a metric.

# Contributing

## How to add new metric?
* first create one file with prefix metric_<name of the metric>.
* write two (2) functions in the new file.
* select set of performance counters needed to derive the metric. See whole list using "perf list" command.
* decide the formula needed to derive the metric based on collected counter data.

## Example
* Let's say we want to derive a metric called branch_mispredicts.
* make a copy of metric.template and renamed it metric_branch_mispredicts
* Select a set of counters needed to derive this metric are, "br_misp_retired.all_branches" and "br_inst_retired.all_branches"
* the formula to calculate "branch_mispredict" ratio is,
* (br_misp_retired.all_branches/br_inst_retired.all_branches)
#### NOTE: Make sure "perf" on the target system has support for these counters.

* With this information, update two functions (init_ and calc_) in the new file as shown below,
### NOTE: Make sure that function name init_ and calc_ has correct suffix with new metric_name.

```
function init_branch_mispredicts() {
  local local_pmu_array=(br_misp_retired.all_branches br_inst_retired.all_branches)
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

function calc_branch_mispredicts() {
  local perf_data_file="$1"
  local metric_name="metric_branch mispredict ratio"
  echo
  echo "================================================="
  echo "Final $metric_name"
  echo "--------------------------------------------------"
  echo "FORMULA: ${metric_name} = (a/b)"
  echo "         where, a=br_misp_retired.all_branches"
  echo "                b=br_inst_retired.all_branches"
  echo "================================================="

  local a=`return_pmu_value "br_misp_retired.all_branches" $perf_data_file `
  local b=`return_pmu_value "br_inst_retired.all_branches" $perf_data_file`

  if [ $a == -1 -o $b == -1 ]; then
    echo "ERROR: ${metric_name} can't be derived. Missing pmus"
  else
    local metric=`echo "scale=$bc_scale;100*(${a}/${b})"| bc -l`
    echo ${metric_name}=${metric}
  fi
  echo
}
```

* Save and try running top level script with -h option.
measure-perf-metrics.sh -h
* You should see new metric listed as supported.
* Use it for real collection/analysis. 
* Once it's ready, contribute it back to the project.

# Generate Perf Map file

When huge page is enabled and the .txt sections are mapped into it, Perf are no longer able to show the symbols. The /tmp/perf-[TID].map is needed for showing symbols correctly with Perf. The gen-perf-map.sh tool is offered to help generating perf-[TID].map file.

## Usage
```
./gen-perf-map.sh -s|-b PATH BASEADDRESS TID
```
* -s|-b: Pass -s if generating symbols for a dynamic library or -b if passing a binary
* PATH: Path to the shared library or binary
* TID: thread ID
* BASEADDRESS: beginning address of .txt section in huge page.

If .txt sections are mapped into huge page with the large_page-c, you can find the TID and BASEADDRESS in the output of console.

## Example

In this example, we run node with a javascript file and use "liblppreload.so" to map .txt sections to huge page. Below is the shell script.
```
#!/usr/bin/bash

LD_PRELOAD=/usr/lib64/liblppreload.so node helloworld.js
```

Then, the command "perf record [shell script]" is performed to record the profiling data. The following is the ouput of console. With it, we can know what TID is, which libarary has been mapped into huge page and its base address. For our example, TID is "8817", the "libnode.so.64" has been mapped into huge page and its base address is "7f36633c3000".
```
TID: 8817
:Base address: 0.Mapping to large pages failed for static code: map region too small
......
Enabling large code pages for /usr/lib64/liblppreload.so Base address: 7f3664990000.
Mapping to large pages failed for /usr/lib64/liblppreload.so: map region too small
Enabling large code pages for /lib/x86_64-linux-gnu/libnode.so.64 Base address: 7f36633c3000. - success.
Enabling large code pages for /lib/x86_64-linux-gnu/libpthread.so.0 Base address: 7f36633a0000.
Mapping to large pages failed for /lib/x86_64-linux-gnu/libpthread.so.0: map region too small
Enabling large code pages for /lib/x86_64-linux-gnu/libc.so.6 Base address: 7f36631ae000.
......
[ perf record: Woken up 1 times to write data ]
[ perf record: Captured and wrote 0.245 MB perf.data (1881 samples) ]
```

Run "gen-perf-map.sh" to generate the perf map file under /tmp/:
```
./gen-perf-map.sh -s /lib/x86_64-linux-gnu/libnode.so.64 7f36633c3000 8817
```
