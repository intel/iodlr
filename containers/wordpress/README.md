# Containerized oss-performance: wordpress workload

## About

This project is intended to be used to execute, in a containerized environment,
the 'wordpress' target of the oss-performance benchmark suite, with updates from Intel(R).

The oss-performance benchmark suite with Intel(R) updates can be found here:
[Updates for OSS Performance at github](https://github.com/intel/Updates-for-OSS-Performance)

## License

The Intel(R) Container for oss-performance with Optimizations for Wordpress is distributed under the MIT License.

You may obtain a copy of the License at:

https://opensource.org/licenses/MIT


## Containers

To accomplish this goal, we have built three containers: wp_base, wp_opt, and wp5.2_base.

* wp_base_http contains the bare minimum needed to execute WordPress 4.2 / PHP7.4 and establish
a baseline. The following modifications were made to wp_base in addition to containerization:
  * php-fpm7.4
* wp_opt_http builds upon wp_base_http and has the following additions
  * BOLTing of PHP
  * PHP Zend framework now uses large pages
  * MariaDB now uses large pages and additional tuning
  * NUMA optimization/multi instance (must be done via pinning, see below)
    * Note that for NUMA optimization/pinning you may do this with the base container if you wish to isolate this optimization.
* wp5.2_base_http builds wp_base_http, but uses WordPress 5.2 and its associated database dump and URLs.  

Note that in order to run a baseline across multiple sockets, you will need to utilize the 1s-bkm.js file in the base user 
directory in the container you wish to run (likely base).  Copy the file over the current my.cnf as shown in the dockerfile.  
This will disable mysql query cache for an appropriate baseline across multiple sockets.

## Building

### Pre-requisites

To build, you must have docker and docker-compose installed:

```
sudo apt install docker.io
sudo apt install docker-compose
```

To build, you may use docker-compose:

```
sudo docker-compose build
```

To see an image list after this you may run:

```
sudo docker image ls
```

Example output:

```
wp_opt_http          latest              3b250734600c        2 minutes ago       1.66GB
wp_base_http         latest              56decbd76dc6        3 minutes ago       1.62GB
```

## Executing the workload

To execute the workload, first start a container (for NUMA gains, see section below instead):

```
sudo docker run -it --privileged wp_opt_http
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
The command will list lcpu ids corresponding to cores on each NUMA node.
Then you must use cpuset-cpus and cpuset-mems flags in docker run to ensure each
instance is running on a single NUMA node.

## Known issues

### Docker proxy

If you are building a docker image behind a corporate proxy, please see instructions here for configuration:
[Docker proxy documentation](https://docs.docker.com/network/proxy/)

You may also refer to this example to get up and running:
```
sudo -E docker-compose build --build-arg http_proxy=$http_proxy --build-arg https_proxy=$https_proxy --build-arg no_proxy=$no_proxy
```
Note this assumes your environment variables are properly set for your network.

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
