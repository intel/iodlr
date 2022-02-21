
# Benchmarking PostgreSQL database server using sysbench client

# sysbench

sysbench is a scriptable multi-threaded benchmark tool based on
LuaJIT. It is most frequently used for database benchmarks, but can also
be used to create arbitrarily complex workloads that do not involve a
database server.

sysbench comes with the following bundled benchmarks:

- `oltp_*.lua`: a collection of OLTP-like database benchmarks
- `fileio`: a filesystem-level benchmark
- `cpu`: a simple CPU benchmark
- `memory`: a memory access benchmark
- `threads`: a thread-based scheduler benchmark
- `mutex`: a POSIX mutex benchmark

# 
For more information on sysbench, please visit [https://github.com/akopytov/sysbench](https://github.com/akopytov/sysbench).

# PostgreSQL

PostgreSQL is a powerful, open source object-relational database system 
that uses and extends the SQL language combined with many features that 
safely store and scale the most complicated data workloads. 

# 
For more information on postgresql, please visit [https://www.postgresql.org/](https://www.postgresql.org/).

# start the docker container with PostgreSQL server image

``` shell
$ docker run --name postgres-instance -e POSTGRES_PASSWORD=mypass -e POSTGRES_USER=sbtest -p 8001:5432 -d postgres-img -c min_dynamic_shared_memory=128
```

# If you need to use hugepages use following command

``` shell
$ docker run --name postgres-instance -e POSTGRES_PASSWORD=mypass -e POSTGRES_USER=sbtest -p 8001:5432 -d postgres-img -c huge_pages=on -c huge_page-size=2MB -c min_dynamic_shared_memory=128
```


** You can start multiple containers listening at different port number 
visible to the external sysbench client.

# prepare data and tables

``` shell
$ sysbench --db-driver=pgsql --pgsql-user=sbtest --pgsql_password=mypass --pgsql-db=sbtest --pgsql-port=8001 --tables=16 --table-size=10000 --threads=256 --time=0 --events=0 --report-interval=1 --time=300 /usr/share/sysbench/oltp_read_write.lua prepare
```

# Run benchmark

``` shell
$ sysbench --db-driver=pgsql --pgsql-user=sbtest --pgsql_password=mypass --pgsql-db=sbtest --pgsql-port=8001 --tables=16 --table-size=10000 --threads=256 --time=0 --events=0 --report-interval=1 --time=300 /usr/share/sysbench/oltp_read_write.lua run
```


