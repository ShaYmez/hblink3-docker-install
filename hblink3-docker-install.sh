#!/bin/bash
# Version 1.6 hblink3-docker-installer
#
##################################################################################
#   Copyright (C) 2021-2022 Shane Daley, M0VUB aka ShaYmez. <support@gb7nr.co.uk>
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software Foundation,
#   Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301  USA
##################################################################################
#
# A tool to install HBlink3 Docker with Debian / Ubuntu support.
# This essentially is a HBlink3 server fully installed with dashboard / SSL ready to go.
# Step 1: Install Debian 9 10 or 11 or Ubuntu 20.04 onwards.. and make sure it has internet and is up to date.
# Step 2: Run this script on the computer.
# Step 4: Reboot after installation.
# This is a docker version and you can use the following comands to control / maintain your server
# cd /etc/hblink3
# docker-compose up -d (starts the hblink3 docker container)
# docker-compose down (shuts down the hblink container and stops the service)
# docker-compose pull (updates the container to the latest docker image)
# systemctl |stop|start|restart|status hbmon (controls the HBMonv2 dash service)
# logs can be found in var/log/hblink or docker comand "docker container logs hblink"
#Lets begin-------------------------------------------------------------------------------------------------
if [ "$EUID" -ne 0 ];
then
  echo ""
  echo "You Must be root to run this script!!"
  exit 1
fi
if [ ! -e "/etc/debian_version" ]
then
  echo ""
  echo "This script is only tested in Debian 9,10 & 11 repo only."
  exit 0
fi
DIRDIR=$(pwd)
LOCAL_IP=$(ip a | grep inet | grep "eth0\|en" | awk '{print $2}' | tr '/' ' ' | awk '{print $1}')
ARC=$(lscpu | grep Arch | awk '{print $2}')
ARMv7l=https://get.docker.com | sh
ARMv8l=https://get.docker.com | sh
X32=https://get.docker.com | sh
X64=https://get.docker.com | sh
INSDIR=/opt/tmp/
HBLINKTMP=/opt/tmp/hblink3
HBMONDIR=/opt/HBMonv2/
HBDIR=/etc/hblink3/
DEP="wget curl git python3 python3-dev python3-pip libffi-dev libssl-dev sed cargo apache2 php snapd figlet"
HBGITREPO=https://github.com/ShaYmez/hblink3.git
HBGITMONREPO=https://github.com/ShaYmez/HBMonv2.git
echo "------------------------------------------------------------------------------"
echo " Installing required software..."
echo "------------------------------------------------------------------------------"
sleep 2
apt-get install -y $DEP
figlet "docker.io"
sleep 2

  echo ""
        echo "------------------------------------------------------------------------------"
        echo "Downloading and installing Docker....."
        echo "------------------------------------------------------------------------------"
        if [ "$ARC" = "x86_64" ];
        then
                curl -sSL https://get.docker.com | sh
                pip3 install docker-compose
                systemctl enable docker
                systemctl start docker
                echo Set userland-proxy to false...
                echo '{ "userland-proxy": false}' > /etc/docker/daemon.json
        elif [ "$ARC" = "armv7l" ];
        then
                curl -sSL https://get.docker.com | sh
                apt-get install -y conntrack
                pip3 install docker-compose
                systemctl enable docker
                systemctl start docker
                echo Set userland-proxy to false...
                echo '{ "userland-proxy": false}' > /etc/docker/daemon.json
        elif [ "$ARC" = "aarch64" ];
        then
                curl -sSL https://get.docker.com | sh
                apt-get install -y conntrack
                pip3 install docker-compose
                systemctl enable docker
                systemctl start docker
                echo Set userland-proxy to false...
                echo '{ "userland-proxy": false}' > /etc/docker/daemon.json
        elif [ "$ARC" = "i686" ];
        then
                curl -sSL https://get.docker.com | sh
                pip3 install docker-compose
                systemctl enable docker
                systemctl start docker
                echo Set userland-proxy to false...
                echo '{ "userland-proxy": false}' > /etc/docker/daemon.json
        fi
echo "Done."
echo "------------------------------------------------------------------------------"
echo "Downloading and installing HBMonv2 Dashboard"
echo "------------------------------------------------------------------------------"
sleep 2
cd /opt/
mkdir tmp
chmod 0755 /opt/tmp/
cd /opt/
git clone $HBGITMONREPO
cd $HBMONDIR
if [ -e monitor.py ]
then
        echo "------------------------------------------------------------------------------"
        echo "It looks like HBMonitor installed correctly. The installation will now proceed. "
        echo "------------------------------------------------------------------------------"
        else
        echo "------------------------------------------------------------------------------"
        echo "I dont see HBMonitor installed! Please check your configuration and try again. Exiting....."
        echo "------------------------------------------------------------------------------"
        exit 0
fi
echo "Done."
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Install HBmonitor configuration"
echo "------------------------------------------------------------------------------"
sleep 2
                pip3 install setuptools wheel
                pip3 install -r requirements.txt
                cp config_SAMPLE.py config.py
                cp utils/hbmon.service /lib/systemd/system/
                cp utils/lastheard /etc/cron.daily/
                chmod +x /etc/cron.daily/lastheard
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Install HBMonv2 Dashboard"
echo "------------------------------------------------------------------------------"
sleep 2
                cd /var/www/html/
                mv /var/www/html/index.html /var/www/html/index_APACHE.html
                cp -a /opt/HBMonv2/html/. /var/www/html/
if [ -e info.php ]
then
        echo "------------------------------------------------------------------------------"
        echo "It looks like the dashboard installed correctly. The installation will now proceed. "
        echo "------------------------------------------------------------------------------"
        else
        echo "------------------------------------------------------------------------------"
        echo "I dont see the dashboard installed! Please check your configuration and try again. Exiting....."
        echo "------------------------------------------------------------------------------"
        exit 0
fi
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Edit your config for HBmonitor..... "CTRL-X" TO EXIT"
echo "------------------------------------------------------------------------------"
        nano /opt/HBMonv2/config.py
echo "Saved!"
sleep 2
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Install HBlink3 folders"
echo "------------------------------------------------------------------------------"
sleep 2
         echo Restart docker...
         systemctl restart docker
         sleep 3

         echo Make config directory...
         mkdir /etc/hblink3
         chmod 755 /etc/hblink3

         echo make json directory...
         mkdir -p /etc/hblink3/json/

         echo get json files...
         cd /etc/hblink3/json
         curl http://downloads.freedmr.uk/downloads/local_subscriber_ids.json -o subscriber_ids.json
         curl https://freestar.network/downloads/talkgroup_ids.json -o talkgroup_ids.json
         curl https://www.radioid.net/static/rptrs.json -o peer_ids.json
         chmod -R 0755 /etc/hblink3/json/
echo "Done"
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Install HBlink3 config"
echo "------------------------------------------------------------------------------"
sleep 2
        echo Install /etc/hblink3/hblink.cfg ... 
cat << EOF > /etc/hblink3/hblink.cfg
# PROGRAM-WIDE PARAMETERS GO HERE
# PATH - working path for files, leave it alone unless you NEED to change it
# PING_TIME - the interval that peers will ping the master, and re-try registraion
#           - how often the Master maintenance loop runs
# MAX_MISSED - how many pings are missed before we give up and re-register
#           - number of times the master maintenance loop runs before de-registering a peer
#
# ACLs:
#
# Access Control Lists are a very powerful tool for administering your system.
# But they consume packet processing time. Disable them if you are not using them.
# But be aware that, as of now, the configuration stanzas still need the ACL
# sections configured even if you're not using them.
#
# REGISTRATION ACLS ARE ALWAYS USED, ONLY SUBSCRIBER AND TGID MAY BE DISABLED!!!
#
# The 'action' May be PERMIT|DENY
# Each entry may be a single radio id, or a hypenated range (e.g. 1-2999)
# Format:
# 	ACL = 'action:id|start-end|,id|start-end,....'
#		--for example--
#	SUB_ACL: DENY:1,1000-2000,4500-60000,17
#
# ACL Types:
# 	REG_ACL: peer radio IDs for registration (only used on HBP master systems)
# 	SUB_ACL: subscriber IDs for end-users
# 	TGID_TS1_ACL: destination talkgroup IDs on Timeslot 1
# 	TGID_TS2_ACL: destination talkgroup IDs on Timeslot 2
#
# ACLs may be repeated for individual systems if needed for granularity
# Global ACLs will be processed BEFORE the system level ACLs
# Packets will be matched against all ACLs, GLOBAL first. If a packet 'passes'
# All elements, processing continues. Packets are discarded at the first
# negative match, or 'reject' from an ACL element.
#
# If you do not wish to use ACLs, set them to 'PERMIT:ALL'
# TGID_TS1_ACL in the global stanza is used for OPENBRIDGE systems, since all
# traffic is passed as TS 1 between OpenBridges
[GLOBAL]
PATH: ./
PING_TIME: 5
MAX_MISSED: 3
USE_ACL: True
REG_ACL: PERMIT:ALL
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL


# NOT YET WORKING: NETWORK REPORTING CONFIGURATION
#   Enabling "REPORT" will configure a socket-based reporting
#   system that will send the configuration and other items
#   to a another process (local or remote) that may process
#   the information for some useful purpose, like a web dashboard.
#
#   REPORT - True to enable, False to disable
#   REPORT_INTERVAL - Seconds between reports
#   REPORT_PORT - TCP port to listen on if "REPORT_NETWORKS" = NETWORK
#   REPORT_CLIENTS - comma separated list of IPs you will allow clients
#       to connect on. Entering a * will allow all.
#
# ****FOR NOW MUST BE TRUE - USE THE LOOPBACK IF YOU DON'T USE THIS!!!****
[REPORTS]
REPORT: True
REPORT_INTERVAL: 60
REPORT_PORT: 4321
REPORT_CLIENTS: 127.0.0.1


# SYSTEM LOGGER CONFIGURAITON
#   This allows the logger to be configured without chaning the individual
#   python logger stuff. LOG_FILE should be a complete path/filename for *your*
#   system -- use /dev/null for non-file handlers.
#   LOG_HANDLERS may be any of the following, please, no spaces in the
#   list if you use several:
#       null
#       console
#       console-timed
#       file
#       file-timed
#       syslog
#   LOG_LEVEL may be any of the standard syslog logging levels, though
#   as of now, DEBUG, INFO, WARNING and CRITICAL are the only ones
#   used.
#
[LOGGER]
LOG_FILE: /tmp/hblink.log
LOG_HANDLERS: console-timed
LOG_LEVEL: DEBUG
LOG_NAME: HBlink

# DOWNLOAD AND IMPORT SUBSCRIBER, PEER and TGID ALIASES
# Ok, not the TGID, there's no master list I know of to download
# This is intended as a facility for other applcations built on top of
# HBlink to use, and will NOT be used in HBlink directly.
# STALE_DAYS is the number of days since the last download before we
# download again. Don't be an ass and change this to less than a few days.
[ALIASES]
TRY_DOWNLOAD: True
PATH: ./
PEER_FILE: peer_ids.json
SUBSCRIBER_FILE: subscriber_ids.json
TGID_FILE: talkgroup_ids.json
PEER_URL: https://www.radioid.net/static/rptrs.json
SUBSCRIBER_URL: https://www.radioid.net/static/users.json
STALE_DAYS: 7

# OPENBRIDGE INSTANCES - DUPLICATE SECTION FOR MULTIPLE CONNECTIONS
# OpenBridge is a protocol originall created by DMR+ for connection between an
# IPSC2 server and Brandmeister. It has been implemented here at the suggestion
# of the Brandmeister team as a way to legitimately connect HBlink to the
# Brandemiester network.
# It is recommended to name the system the ID of the Brandmeister server that
# it connects to, but is not necessary. TARGET_IP and TARGET_PORT are of the
# Brandmeister or IPSC2 server you are connecting to. PASSPHRASE is the password
# that must be agreed upon between you and the operator of the server you are
# connecting to. NETWORK_ID is a number in the format of a DMR Radio ID that
# will be sent to the other server to identify this connection.
# other parameters follow the other system types.
#
# ACLs:
# OpenBridge does not 'register', so registration ACL is meaningless.
# Proper OpenBridge passes all traffic on TS1.
# HBlink can extend OPB to use both slots for unit calls only.
# Setting "BOTH_SLOTS" True ONLY affects unit traffic!
# Otherwise ACLs work as described in the global stanza
[OBP-1]
MODE: OPENBRIDGE
ENABLED: True
IP:
PORT: 62035
NETWORK_ID: 3129100
PASSPHRASE: password
TARGET_IP: 1.2.3.4
TARGET_PORT: 62035
BOTH_SLOTS: True
USE_ACL: True
SUB_ACL: DENY:1
TGID_ACL: PERMIT:ALL

# MASTER INSTANCES - DUPLICATE SECTION FOR MULTIPLE MASTERS
# HomeBrew Protocol Master instances go here.
# IP may be left blank if there's one interface on your system.
# Port should be the port you want this master to listen on. It must be unique
# and unused by anything else.
# Repeat - if True, the master repeats traffic to peers, False, it does nothing.
#
# MAX_PEERS -- maximun number of peers that may be connect to this master
# at any given time. This is very handy if you're allowing hotspots to
# connect, or using a limited computer like a Raspberry Pi.
#
# ACLs:
# See comments in the GLOBAL stanza
[MASTER-1]
MODE: MASTER
ENABLED: True
REPEAT: True
MAX_PEERS: 10
EXPORT_AMBE: False
IP:
PORT: 54000
PASSPHRASE: s3cr37w0rd
GROUP_HANGTIME: 5
USE_ACL: True
REG_ACL: DENY:1
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL

# PEER INSTANCES - DUPLICATE SECTION FOR MULTIPLE PEERS
# There are a LOT of errors in the HB Protocol specifications on this one!
# MOST of these items are just strings and will be properly dealt with by the program
# The TX & RX Frequencies are 9-digit numbers, and are the frequency in Hz.
# Latitude is an 8-digit unsigned floating point number.
# Longitude is a 9-digit signed floating point number.
# Height is in meters
# Setting Loose to True relaxes the validation on packets received from the master.
# This will allow HBlink to connect to a non-compliant system such as XLXD, DMR+ etc.
#
# ACLs:
# See comments in the GLOBAL stanza
[REPEATER-1]
MODE: PEER
ENABLED: True
LOOSE: False
EXPORT_AMBE: False
IP: 
PORT: 54001
MASTER_IP: 172.16.1.1
MASTER_PORT: 54000
PASSPHRASE: homebrew
CALLSIGN: W1ABC
RADIO_ID: 312000
RX_FREQ: 449000000
TX_FREQ: 444000000
TX_POWER: 25
COLORCODE: 1
SLOTS: 1
LATITUDE: 38.0000
LONGITUDE: -095.0000
HEIGHT: 75
LOCATION: Anywhere, USA
DESCRIPTION: This is a cool repeater
URL: www.w1abc.org
SOFTWARE_ID: 20170620
PACKAGE_ID: MMDVM_HBlink
GROUP_HANGTIME: 5
OPTIONS:
USE_ACL: True
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL

[XLX-1]
MODE: XLXPEER
ENABLED: True
LOOSE: True
EXPORT_AMBE: False
IP: 
PORT: 54002
MASTER_IP: 172.16.1.1
MASTER_PORT: 62030
PASSPHRASE: passw0rd
CALLSIGN: W1ABC
RADIO_ID: 312000
RX_FREQ: 449000000
TX_FREQ: 444000000
TX_POWER: 25
COLORCODE: 1
SLOTS: 1
LATITUDE: 38.0000
LONGITUDE: -095.0000
HEIGHT: 75
LOCATION: Anywhere, USA
DESCRIPTION: This is a cool repeater
URL: www.w1abc.org
SOFTWARE_ID: 20170620
PACKAGE_ID: MMDVM_HBlink
GROUP_HANGTIME: 5
XLXMODULE: 4004
USE_ACL: True
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL
EOF

        echo Install /etc/hblink3/rules.py ...
cat << EOF > /etc/hblink3/rules.py
'''
THIS EXAMPLE WILL NOT WORK AS IT IS - YOU MUST SPECIFY YOUR OWN VALUES!!!
This file is organized around the "Conference Bridges" that you wish to use. If you're a c-Bridge
person, think of these as "bridge groups". You might also liken them to a "reflector". If a particular
system is "ACTIVE" on a particular conference bridge, any traffid from that system will be sent
to any other system that is active on the bridge as well. This is not an "end to end" method, because
each system must independently be activated on the bridge.
The first level (e.g. "WORLDWIDE" or "STATEWIDE" in the examples) is the name of the conference
bridge. This is any arbitrary ASCII text string you want to use. Under each conference bridge
definition are the following items -- one line for each HBSystem as defined in the main HBlink
configuration file.
    * SYSTEM - The name of the sytem as listed in the main hblink configuration file (e.g. hblink.cfg)
        This MUST be the exact same name as in the main config file!!!
    * TS - Timeslot used for matching traffic to this confernce bridge
        XLX connections should *ALWAYS* use TS 2 only.
    * TGID - Talkgroup ID used for matching traffic to this conference bridge
        XLX connections should *ALWAYS* use TG 9 only.
    * ON and OFF are LISTS of Talkgroup IDs used to trigger this system off and on. Even if you
        only want one (as shown in the ON example), it has to be in list format. None can be
        handled with an empty list, such as " 'ON': [] ".
    * TO_TYPE is timeout type. If you want to use timers, ON means when it's turned on, it will
        turn off afer the timout period and OFF means it will turn back on after the timout
        period. If you don't want to use timers, set it to anything else, but 'NONE' might be
        a good value for documentation!
    * TIMOUT is a value in minutes for the timout timer. No, I won't make it 'seconds', so don't
        ask. Timers are performance "expense".
    * RESET is a list of Talkgroup IDs that, in addition to the ON and OFF lists will cause a running
        timer to be reset. This is useful   if you are using different TGIDs for voice traffic than
        triggering. If you are not, there is NO NEED to use this feature.
'''

BRIDGES = {
    'WORLDWIDE': [
            {'SYSTEM': 'MASTER-1',    'TS': 1, 'TGID': 1,    'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'ON',  'ON': [2,], 'OFF': [9,10], 'RESET': []},
            {'SYSTEM': 'CLIENT-1',    'TS': 1, 'TGID': 3100, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'ON',  'ON': [2,], 'OFF': [9,10], 'RESET': []},
        ],
    'ENGLISH': [
            {'SYSTEM': 'MASTER-1',    'TS': 1, 'TGID': 13,   'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [3,], 'OFF': [8,10], 'RESET': []},
            {'SYSTEM': 'CLIENT-2',    'TS': 1, 'TGID': 13,   'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [3,], 'OFF': [8,10], 'RESET': []},
        ],
    'STATEWIDE': [
            {'SYSTEM': 'MASTER-1',    'TS': 2, 'TGID': 3129, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [4,], 'OFF': [7,10], 'RESET': []},
            {'SYSTEM': 'CLIENT-2',    'TS': 2, 'TGID': 3129, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [4,], 'OFF': [7,10], 'RESET': []},
        ]
}

'''
list the names of each system that should bridge unit to unit (individual) calls.
'''

UNIT = ['ONE', 'TWO']

'''
This is for testing the syntax of the file. It won't eliminate all errors, but running this file
like it were a Python program itself will tell you if the syntax is correct!
'''

if __name__ == '__main__':
    from pprint import pprint
    pprint(BRIDGES)
    print(UNIT)
EOF
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Set up logging"
echo "------------------------------------------------------------------------------"
        mkdir -p /var/log/hblink
        touch /var/log/hblink/hblink.log
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Install docker-compose YAML and set up to run the server"
echo "------------------------------------------------------------------------------"
sleep 2
                cd $INSDIR
                git clone $HBGITREPO
                cd $HBLINKTMP
                cp docker-compose.yml /etc/hblink3/docker-compose.yml
                cd $HBDIR
if [ -e docker-compose.yml ]
then
        echo "----------------------------------------------------------------------------------------------"
        echo "It looks like the docker-compose file installed correctly. The installation will now proceed. "
        echo "----------------------------------------------------------------------------------------------"
        else
        echo "-----------------------------------------------------------------------------------------------"
        echo "I dont see the docker-compose file! Please check your configuration and try again. Exiting....."
        echo "-----------------------------------------------------------------------------------------------"
        exit 0
fi
echo "Done"
sleep 2
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Set up permissions"
echo "------------------------------------------------------------------------------"
        chown -R 54000 /etc/hblink3
        chown -R 54000 /var/log/hblink
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Wake up the container and pull latest docker image from ShaYmez"
echo "------------------------------------------------------------------------------"
        docker-compose up -d
        sleep 10
        docker-compose down
echo "Done."
sleep 2
echo "Stopping container....."
sleep 2
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "The installation will now complete.... Please wait...."
echo "------------------------------------------------------------------------------"
sleep 5
echo ""
echo ""
echo "-------------------------------------------------------------------------------------------------"
echo "If you would like to cancel please hit "CTRL-X" now...  Otherwise HBlink will start automatically"
echo "-------------------------------------------------------------------------------------------------"
        sleep 10
        clear
        sleep 2
echo "Starting HBlink....."
        sleep 5
        cd $HBDIR
        docker-compose up -d
        sleep 5
figlet "HBlink Master"
sleep 3
        docker container logs hblink
echo "Done."
sleep 2
echo "Starting HBmon....."
        systemctl enable hbmon
        systemctl start hbmon
figlet "HBMonV2
echo "Done."
sleep 2
echo ""
echo ""
echo "*************************************************************************"
echo ""
echo "            The HBlink-MasterServer Installation Is Complete!            "
echo ""
echo "                ******* Now reboot the server. *******                   "
echo "        Use 'docker container logs hblink' to check the status.          "
echo "                  logs are part in /var/log/hblink.                      "
echo "  Just make sure this computer can be accessed over UDP specified port   "
echo "  You will need to edit your config and then run the following command   "
echo ""
echo "                           cd /etc/hblink3                               "
echo "                         docker-compose up -d                            "
echo "      More documentation can be found on the HBlink3 git repo            "
echo "         https://github.com/ShaYmez/hblink3-docker-install               "
echo ""
echo "                     Thanks for using this script.                       "
echo "                Copyright © 2022 Shane Daley - M0VUB                     "
echo "   More information can be found @ https://freestar.network/development  "
echo ""
echo "*************************************************************************"
