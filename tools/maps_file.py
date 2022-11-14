#!/usr/bin/python3
import sys

class MapsFile:
    def __init__(self, name):
        self.name = name
        self.lines = []

    def write_file(self, name):
        with open(name, "w") as file:
            for line in self.lines:
                file.write("%s %s\n" % (line[0], line[1]))
    
    def calculate_vir_adr(self, baseaddr):
        with open(self.name) as file:
            for line in file:
                larray = line.rstrip().split(" ", 1)
                larray[0] = "%016lx" % (int(larray[0], 16) + baseaddr)
                self.lines.append(larray)
                

if __name__ == "__main__":
    src = "./nm-output.txt"
    dest = "./tmp.map"
    fd = MapsFile(src)
    
    fd.calculate_vir_adr(int(sys.argv[1], 16))

    fd.write_file(dest)
