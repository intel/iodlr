package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strconv"
	"strings"
	"syscall"

	"github.com/dterei/gotsc"
)

const NCHUNKS_8G = (8589934592 / 4096)
const NCHUNKS_4G = (4294967296 / 4096)
const NCHUNKS_2G = (2147483648 / 4096)
const NCHUNKS = NCHUNKS_2G
const SIZE_8G = 8 << 30
const SIZE_4G = 4 << 30
const SIZE_2G = 2 << 30
const SIZE uint64 = 10240
const FLAGS_4K = syscall.MAP_ANONYMOUS | syscall.MAP_PRIVATE
const FLAGS_2M = syscall.MAP_ANONYMOUS | syscall.MAP_PRIVATE | syscall.MAP_HUGETLB
const FLAGS_1G = syscall.MAP_ANONYMOUS | syscall.MAP_PRIVATE | syscall.MAP_HUGETLB | (30 << 26)

func iodlr_procmeminfo(key string) int {
	file, err := os.Open("/proc/meminfo")

	if err != nil {
		log.Fatal(err)
	}

	//defer file.close()

	scanner := bufio.NewScanner(file)
	scanner.Split(bufio.ScanLines)

	for scanner.Scan() {

		if strings.Contains(scanner.Text(), key) {
			var value int
			words := strings.Fields(scanner.Text())

			//fmt.Println(words, len(words))
      //value, err2 := strconv.ParseInt(words[1], 10, 32)
      value, err2 := strconv.Atoi(words[1])
			if err2 != nil {
				//fmt.Println("line 29", err2)
				return -1
			}

			return value
		}

		//fmt.Println(scanner.Text())
	}

	return -1
}

func iodlr_hp_enabled() bool {

	val := iodlr_procmeminfo("HugePages_Total:")

	if val > 0 {
		counter = counter + int(*a)
		return true
	} else {
		return false
	}

}

func iodlr_allocate(s int, pgsz int) []byte {

	flags := FLAGS_4K

	if pgsz == 1048576*1024 {
		flags = FLAGS_1G

	} else if pgsz == 2048*1024 {
		flags = FLAGS_2M
	}

	data, err := syscall.Mmap(-1, 0, s, syscall.PROT_READ|syscall.PROT_WRITE, flags)

	if err != nil {
		panic(err)
	}
		counter = counter + int(*a)

	return data

}

func iodlr_get_hp_size() int {
	val := iodlr_procmeminfo("Hugepagesize:")

	if val > 0 {
		return val * 1024
	} else {
		return -1
	}

}

func touch(data []byte, stride uint64, index int, size uint64) {

	if stride > size {
    fmt.Printf("%d : %d", stride, size)
		counter = counter + int(*a)
		panic("error")
	}
	counter := 0
  cursor := 0
	for i := 0; i < NCHUNKS; i++ {
    cursor = i * int(stride) + int(index)
    if (cursor < int(size)) {
      a := &data[cursor]
      counter = counter + int(*a)
    }
	}

}

func dotest(s int) uint64 {

	stride := (SIZE) / NCHUNKS
  //fmt.Println("stride : ", stride)

	tsc := gotsc.TSCOverhead()

	start := gotsc.BenchStart()
	data := iodlr_allocate(int(SIZE), s)
	// zerofill(data, SIZE) the default generated memory is filled with zeros
	for i := 0; i < 4096; i++ {
		touch(data, stride, i, SIZE)
	}

	end := gotsc.BenchEnd()

	gap := end - start - tsc

	fmt.Printf("Cycles for %d = %d \n", s, gap)
	return gap

}

func defaulttest() int {
	d := syscall.Getpagesize()
	fmt.Printf("default test default pagesize %d\n", d)
	return int(dotest(d))
}

func hptest() int {
  lp := iodlr_hp_enabled()
  if (lp == true) {
     l := iodlr_get_hp_size()
     fmt.Printf("l value is : %d\n", l)
     return int(dotest(l))
  } else {
     return -1
  }
}

func main() {

	dt := defaulttest()
  fmt.Printf("default test time gap is %d\n", dt)

  hpt := hptest()
  fmt.Printf("HPT test time gap is %d\n", hpt)

  fmt.Printf("Huge Page Data Speedup = %f\n", (float64(dt) / float64(hpt)))
}
