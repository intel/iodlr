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

