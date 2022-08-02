# Containerized oss-performance: WordPress workload

## About

This project is intended to be used to execute, in a containerized environment,
the 'WordPress' target of the oss-performance benchmark suite, with updates from Intel(R).

The oss-performance benchmark suite with Intel(R) updates can be found here:
[Updates for OSS Performance at github](https://github.com/intel/Updates-for-OSS-Performance)

## License

The Intel(R) Container for oss-performance with Optimizations for WordPress is distributed under the MIT License.

You may obtain a copy of the License at:

https://opensource.org/licenses/MIT


## Containers

To accomplish this goal, we have built four containers: wp4.2_php7.4_base, wp4.2_php7.4_opt, wp5.6_php8.0_base, wp5.6_php8.0_opt.

* wp4.2_php7.4_base_https contains the bare minimum needed to execute WordPress4.2 / PHP7.4 and establish
a baseline. The following modifications were made to wp_base in addition to containerization:
  * php-fpm7.4
* wp4.2_php7.4_opt_https builds upon wp4.2_php7.4_base_https and has the following additions:
  * BOLTing of PHP
  * Intel QAT accelerator with SW mode for TLS1.3
  * PHP Zend framework now uses large pages
  * MariaDB now uses large pages and additional tuning
  * NUMA optimization/multi instance (must be done via pinning, see below)
    * Note that for NUMA optimization/pinning you may do this with the base container if you wish to isolate this optimization.
    
* wp5.6_php8.0_base_https contains the bare minimum needed to execute WordPress5.6 / PHP8.0.
* wp5.6_php8.0_opt_https builds upon wp5.6_php8.0_base_https and has the following additions:
  * PHP JIT
  * BOLTing of PHP
  * Intel QAT accelerator with SW mode for TLS1.3
  * PHP Zend framework now uses large pages
  * MariaDB now uses large pages and additional tuning
  * NUMA optimization/multi instance (must be done via pinning, see below)
    * Note that for NUMA optimization/pinning you may do this with the base container if you wish to isolate this optimization.  

Note that in order to run a baseline across multiple sockets, you will need to utilize the 1s-bkm.js file in the base user
directory in the container you wish to run (likely base).  Copy the file over the current my.cnf as shown in the dockerfile.
This will disable mysql query cache for an appropriate baseline across multiple sockets.

## How to build

### Pre-requisites

To build, you must have docker and docker-compose installed:

```
sudo apt install docker.io
sudo apt install docker-compose
```

To build all containers, you may use docker-compose:

```
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build \
  --progress=plain
```

To build a single container, you may use docker-compose as following example:

```
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build \
  --progress=plain \ 
  wp4.2_php7.4_base_https
```


To see an image list after this you may run:

```
docker image ls
```

Example output:

```
wp5.6_php8.0_opt_https                                                    latest                             042f6b6f5e67   About a minute ago   1.76GB
wp5.6_php8.0_base_https                                                   latest                             ac13b8af0a6a   10 minutes ago       1.09GB
wp4.2_php7.4_opt_https                                                    latest                             c7362eb36dac   16 minutes ago       1.74GB
wp4.2_php7.4_base_https                                                   latest                             2a88d5f6a925   25 minutes ago       1.08GB
```

## How to executing the workload

To execute the workload, first start a container (for NUMA gains, see section below instead):

```
docker run -it --privileged wp4.2_php7.4_opt_https
```

Now inside the container you may run:

```
./quickrun.sh
```

### NUMA pinning and multiple instances

To take advantage of multiple instances with respect to NUMA optimizations, run
```
lscpu
```
The command will list cpu ids corresponding to cores on each NUMA node.
Then you must use cpuset-cpus and cpuset-mems flags in docker run to ensure each
instance is running on a single NUMA node.

### Automatic script

An alternative way to execute the workload is use run.sh script, which will launch the workload and
calculate the total TPS (transactions per second).
Below example shows it runs 8 instances of wp_base_http image with NUMA pinning.
```
$ ./run.sh --image wp4.2_php7.4_opt_https --count 8 --numa-pinning
-------------------------------------------------------------
Creating temporary directory /tmp/run-DHzZTK85da for logfile.

-------------------------------------------------------------
Running 8 wp4.2_php7.4_opt_https instance(s) with NUMA pinning.
...
-------------------------------------------------------------
All instances are completed.
-------------------------------------------------------------
TPS of 8 instances: 791.3 786.65 787.78 787.33 791.65 788.88 783.91 786.39
Total TPS: 6303.89
```

## Known issues

### Docker proxy

If you are building a docker image behind a corporate proxy, please see instructions here for configuration:
[Docker proxy documentation](https://docs.docker.com/network/proxy/)

You may also refer to this example to get up and running:
```
COMPOSE_DOCKER_CLI_BUILD=1 DOCKER_BUILDKIT=1 docker-compose build --build-arg http_proxy=$http_proxy --build-arg https_proxy=$https_proxy --build-arg no_proxy=$no_proxy
```
Note this assumes your environment variables are properly set for your network.

### Siege Lifting hang

Siege has a known issue: https://github.com/JoeDog/siege/issues/66

You may meet Siege lifting hang during test
```
Lifting the server siege...
```

#### Apparmor

There are instances where apparmor may cause mariadb to not start, particularly when mysql is installed on the host system running apparmor.

In summary, on the host system mysql is installed with an apparmor profile.  Apparmor enforces rules based on binary paths.
When we use –privileged it is essentially telling apparmor to not use a profile, however apparmor does do a search for matching paths (as I understand it) so the host mysql app armor profile blocks the read anyway.

An excerpt from the following link:

https://github.com/moby/moby/issues/7512

“This is because apparmor applies profiles based on the binary paths. When we run the container in privileged mode docker only tells apparmor that we are not setting the profile so leave this unconfined. However, by not specifying a profile, apparmor looks at the binary path and sees if it has any profiles matching the binary and automatically applies them.
A few things that I would suggest you doing is not have the profiles installed on your host when using apparmor if you are running everything in containers.
The other is you should not run a database container in privileged mode. Mysql should not need extra capabilities and you don't want to open up access to your host for a database that does not require it. Very few applications actually require privileged mode and mysql is definitely not one of them.”

The workaround:

To temporarily disable the app armor profile on your host run:
sudo ln -s /etc/apparmor.d/usr.sbin.mysqld /etc/apparmor.d/disable/
sudo apparmor_parser -R /etc/apparmor.d/usr.sbin.mysqld

Now you can run the container as usual

Re-enable:

sudo rm /etc/apparmor.d/disable/usr.sbin.mysqld
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.mysqld
sudo aa-status

App armor enable/disable steps from this link:

https://askubuntu.com/questions/1144497/how-to-disable-apparmor-for-mysql
