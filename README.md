# HBlink3 Docker Installer
This is a multi-arch docker installer for HBlink3 and HBmonV2 combined

![HBlink](img/HBLINK_logoV1.png "HBlink")

## Additional Features
### Docker Multi-Arch build
Docker container pre-built for multi-arch!

* x86_64
* armv6 / armv7
* aarch64
* ppc64
* lots more!

This installer builds the entire server! It includes all of the dependencies needed to run HBlink3 within docker via docker-compose. The install also includes
HBMonv2 which is a dashboard designed for HBlink3 by SP2ONG! This runs side by side but at this time is build on the host machine. HBMonv2 is controlled by a system unit file which runs the python code on the host.

This installer includes all the usual libs and packages including apache2, php and python3.

### Prerequisite
System must be dabian 9, 10 or 11. This script has been tested on most architectures but the system requires at a minimum must meet the minimum requirements to run docker and additional procceses! The system must be upto date and have Git installed. You can install Git from the CLI.
```sh
apt-get install -y git
```
### Installation
1. Have preferably a clean Dabian/Ubuntu system. Mkae sure your system is up to date with the latest apt repository database. You must be super user "root" to run this installer successfully.
```sh
apt update
sudo su
```
2. It is very important that the installer runs from the opt dir. We will then want to get this repository and clone it to the /opt directory.
```sh
cd /opt
git clone https://github.com/ShaYmez/hblink3-docker-install
```
3. Now enter the cloned repo and execute the install script.
```sh
cd hblink3-docker-install
./hblink3-docker-install.sh
```
4. follow the install and any prompts! It it will prompt you for kernel updates if neccassary.
5. Once the installtion is complete it is recommended to reboot the machine.
6. To interact with HBlink3 in docker you need to enter the HBlink3 directory
```sh
cd /etc/hblink3
```
7. You can only interact with HBlink3 in this directory. Use the following commands to interact with the installation.
```sh
docker-compose up -d
docker-compose down
docker-compose restart
docker-compose pull
```
8. Edit your configuration before deployment!
```sh
nano hblink.cfg
nano rules.py
```
9. Check the logs for errors!
```sh
docker container logs hblink
or
/var/log/hblink/hblink.log
```
10. Interact with HBmov2 (Dashboard engine)
```sh
systemctl start|stop|restart|status hbmon
```

![New HBMonv2 Banner](img/HBLINK_logoV2.png "HBMonv2")

Within this installtion includes the new HBMonv2 by Weldek SP2ONG
* Better dashboard for monitoring per page
* Python build	
* Websocket connection to web interface	
* Can be easily secured by SSL / Websocket secure	
* Includes lastheard database with auto cron installed	
* Includes talkgroup html editable page	

## Easy Installation And Upgrade
The installtion can be upgraded either by the use of a future scripts or by manually backing up your configuration and re-running the install script. Also the ability and really cool feature of docker-compose is that its easy to update the container with fresh images! Run by a simple command. Make sure you are in the /etc/hblink3 dir.
```sh
docker-compose pull
```

## Ports to forward
```sh
http 80/tcp
https 443/tcp
report 4321/tcp
websocket 9000/udp
MMDVM 62030-62031/udp
OBP 62032-62050/udp
ssh 22/tcp
```

### More to come...
We will be updating this repository to include more documentation. In the mean time learn about docker @ https://docker.com and visit the HBlink3 official repo for further documentation! https://github.com/HBLink-org/
