#!/bin/bash
# Docker version alpine-3.18
# Version 1.5.0 (13122025) hblink3-docker-installer
# Release: Debian 13 (Trixie) Support Verified
#
##################################################################################
#   Copyright (C) 2021-2025 Shane Daley, M0VUB aka ShaYmez. <shane@freestar.network>
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
# A tool to install HBlink3 Docker with Debian 10-13 / Ubuntu 20.04 support.
# This essentially is a HBlink3 server fully installed with dashboard ready to go.
# Step 1: Install Debian 10, 11, 12, or 13 (Trixie) or Ubuntu 20.04 and make sure it has internet and is up to date.
# Step 2: Run this script on the computer.
# Step 3: Reboot after installation.
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
  echo "This script is only tested in Debian 10, 11, 12 & 13 (Trixie)."
  exit 0
fi
DIRDIR=$(pwd)
LOCAL_IP=$(ip a | grep inet | grep "eth0\|en" | awk '{print $2}' | tr '/' ' ' | awk '{print $1}')
EXTERNAL_IP=$(curl -s --connect-timeout 5 https://ipecho.net/plain 2>/dev/null || echo "Unable to detect")
ARC=$(lscpu | grep Arch | awk '{print $2}')
VERSION=$(sed 's/\..*//' /etc/debian_version)
ARMv7l=https://get.docker.com | sh
ARMv8l=https://get.docker.com | sh
X32=https://get.docker.com | sh
X64=https://get.docker.com | sh
INSDIR=/opt/tmp/
HBLINKTMP=/opt/tmp/hblink3
HBMONDIR=/opt/HBMonv2/
HBDIR=/etc/hblink3/
DEP="wget curl git sudo python3 python3-dev python3-pip libffi-dev libssl-dev conntrack sed cargo apache2 php snapd figlet ca-certificates gnupg lsb-release"
DEP1="wget curl git sudo python3 python3-dev python3-pip libffi-dev libssl-dev conntrack sed cargo apache2 php snapd figlet ca-certificates gnupg lsb-release"
DEP2="wget sudo curl git python3 python3-dev python3-pip libffi-dev libssl-dev conntrack sed cargo apache2 php php-mysqli snapd figlet ca-certificates gnupg lsb-release"
HBGITREPO=https://github.com/ShaYmez/hblink3.git
HBGITMONREPO=https://github.com/ShaYmez/HBMonv2.git
echo ""
echo "------------------------------------------------------------------------------"
echo "Downloading and installing required software & dependencies....."
echo "------------------------------------------------------------------------------"

install_docker_and_dependencies() {
        local version=$1
        echo "Detected Debian version: $version"
        
        # Install base dependencies
        apt-get update
        apt-get install -y $DEP
        sleep 2
        
        # Remove old Docker versions if present
        apt-get remove docker docker-engine docker.io containerd runc 2>/dev/null || true
        
        # Add Docker GPG key
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Install docker-compose based on Debian version
        if [ $version -ge 12 ]; then
                # For Debian 12+ use docker-compose-plugin or install from GitHub
                # Note: We prefer docker-compose-plugin from apt repos when available for security
                if apt-get install -y docker-compose-plugin 2>/dev/null; then
                        echo "docker-compose-plugin installed successfully"
                        # Create wrapper script for docker-compose command compatibility
                        # docker-compose-plugin provides 'docker compose' but scripts use 'docker-compose'
                        if [ ! -f /usr/local/bin/docker-compose ]; then
                                echo "Creating docker-compose wrapper script..."
                                cat > /usr/local/bin/docker-compose << 'EOF'
#!/bin/sh
# Wrapper script to provide docker-compose command using docker compose plugin
exec docker compose "$@"
EOF
                                chmod +x /usr/local/bin/docker-compose
                        fi
                else
                        echo "Installing docker-compose from GitHub releases..."
                        # Fallback to GitHub releases for official Docker Compose binary
                        # Downloaded from official Docker GitHub repository over HTTPS
                        curl -SL https://github.com/docker/compose/releases/latest/download/docker-compose-linux-$(uname -m) -o /usr/local/bin/docker-compose
                        chmod +x /usr/local/bin/docker-compose
                        ln -sf /usr/local/bin/docker-compose /usr/bin/docker-compose 2>/dev/null || true
                fi
        else
                # For Debian 10-11 use apt package
                apt-get install -y docker-compose
        fi
        
        # Enable and start Docker
        systemctl enable docker
        systemctl start docker
        figlet "docker.io"
        
        echo "Set userland-proxy to false..."
        echo '{ "userland-proxy": false}' > /etc/docker/daemon.json
}

        if [ $VERSION = 10 ] || [ $VERSION = 11 ]; then
                install_docker_and_dependencies $VERSION
                                
        elif [ $VERSION = 12 ] || [ $VERSION = 13 ]; then
                # Debian 12 (Bookworm) and 13 (Trixie) support
                echo "Installing for Debian $VERSION..."
                install_docker_and_dependencies $VERSION
                                
        else
        echo "-------------------------------------------------------------------------------------------"
        echo "Operating system not supported! Please check you are running Debian 10-13. Exiting....."
        echo "-------------------------------------------------------------------------------------------"
        exit 0
fi
echo "Done."
echo "------------------------------------------------------------------------------"
echo "Installing control scripts /usr/local/sbin....."
echo "------------------------------------------------------------------------------"
        cd "$DIRDIR/usr/local/sbin"
        cp -p menu /usr/local/sbin/hblink-menu
        cp -p flush /usr/local/sbin/hblink-flush
        cp -p update /usr/local/sbin/hblink-update
        cp -p upgrade /usr/local/sbin/hblink-upgrade
        cp -p stop /usr/local/sbin/hblink-stop
        cp -p start /usr/local/sbin/hblink-start
        cp -p restart /usr/local/sbin/hblink-restart
        cp -p initial-setup /usr/local/sbin/hblink-initial-setup
        cp -p uninstall /usr/local/sbin/hblink-uninstall
if [ -e /usr/local/sbin/hblink-menu ]
then
        echo "----------------------------------------------------------------------------------------------"
        echo "It looks like the control scripts installed correctly. Setting permissions..... "
        echo "----------------------------------------------------------------------------------------------"
        else
        echo "-----------------------------------------------------------------------------------------------"
        echo "I dont see the control scripts! Please check your configuration and try again. Exiting....."
        echo "-----------------------------------------------------------------------------------------------"
        exit 0
fi
# Permissions for control scripts are set here...
        chmod 755 /usr/local/sbin/hblink-menu
        chmod 755 /usr/local/sbin/hblink-flush
        chmod 755 /usr/local/sbin/hblink-update
        chmod 755 /usr/local/sbin/hblink-upgrade
        chmod 755 /usr/local/sbin/hblink-stop
        chmod 755 /usr/local/sbin/hblink-start
        chmod 755 /usr/local/sbin/hblink-restart
        chmod 755 /usr/local/sbin/hblink-initial-setup
        chmod 755 /usr/local/sbin/hblink-uninstall
# Save installer directory path for re-installation
        mkdir -p /etc/hblink3
        echo "$DIRDIR" > /etc/hblink3/.installer_path
        chmod 644 /etc/hblink3/.installer_path
echo "Done."
        
echo "------------------------------------------------------------------------------"
echo "Downloading and installing HBMonv2 Dashboard....."
echo "------------------------------------------------------------------------------"
sleep 2
cd /opt/
mkdir -p tmp
chmod 0755 /opt/tmp/
cd /opt/
git clone $HBGITMONREPO
cd $HBMONDIR
if [ -e monitor.py ]
then
        echo "--------------------------------------------------------------------------------"
        echo "It looks like HBMonitor installed correctly. The installation will now proceed. "
        echo "--------------------------------------------------------------------------------"
        else
        echo "-------------------------------------------------------------------------------------------"
        echo "I dont see HBMonitor installed! Please check your configuration and try again. Exiting....."
        echo "-------------------------------------------------------------------------------------------"
        exit 0
fi
echo "Done."
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Installing HBMonv2 configuration....."
echo "------------------------------------------------------------------------------"
sleep 2

# Helper function to install pip packages with Debian 12+ compatibility
pip_install() {
        local args="$@"
        if [ $VERSION -ge 12 ]; then
                # For Debian 12+, try with --break-system-packages flag first
                pip3 install --break-system-packages $args 2>/dev/null || pip3 install $args
        else
                # For Debian 10-11, use standard pip installation
                pip3 install $args
        fi
}

                echo "Installing Python dependencies..."
                pip_install setuptools wheel
                pip_install -r requirements.txt
                pip_install attrs --force
                
        echo Install /opt/HBMonv2/config.py ...
cat << EOF > /opt/HBMonv2/config.py
CONFIG_INC      = True                           # Include HBlink stats
HOMEBREW_INC    = True                           # Display Homebrew Peers status
LASTHEARD_INC   = True                           # Display lastheard table on main page
BRIDGES_INC     = False                          # Display Bridge status and button
EMPTY_MASTERS   = False                          # Display Enable (True) or DISABLE (False) empty masters in status
#
HBLINK_IP       = '127.0.0.1'                    # HBlink's IP Address
HBLINK_PORT     = 4321                           # HBlink's TCP reporting socket
FREQUENCY       = 10                             # Frequency to push updates to web clients
CLIENT_TIMEOUT  = 0                              # Clients are timed out after this many seconds, 0 to disable

# Generally you don't need to use this but
# if you don't want to show in lastherad received traffic from OBP link put NETWORK ID 
# for example: "260210,260211,260212"
OPB_FILTER = ""

# Files and stuff for loading alias files for mapping numbers to names
PATH            = './'                           # MUST END IN '/'
PEER_FILE       = 'peer_ids.json'                # Will auto-download 
SUBSCRIBER_FILE = 'subscriber_ids.json'          # Will auto-download 
TGID_FILE       = 'talkgroup_ids.json'           # User provided
LOCAL_SUB_FILE  = 'local_subscriber_ids.json'    # User provided (optional, leave '' if you don't use it)
LOCAL_PEER_FILE = 'local_peer_ids.json'          # User provided (optional, leave '' if you don't use it)
LOCAL_TGID_FILE = 'local_talkgroup_ids.json'     # User provided (optional, leave '' if you don't use it)
FILE_RELOAD     = 14                             # Number of days before we reload DMR-MARC database files
PEER_URL        = 'https://radioid.net/static/rptrs.json'
SUBSCRIBER_URL  = 'https://radioid.net/static/users.json'

# Settings for log files
LOG_PATH        = './log/'             # MUST END IN '/'
LOG_NAME        = 'hbmon.log'
EOF
                cp utils/hbmon.service /lib/systemd/system/
                cp utils/lastheard /etc/cron.daily/
                chmod +x /etc/cron.daily/lastheard
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Installing HBMonv2 HTML Dashboard....."
echo "------------------------------------------------------------------------------"
sleep 2
                cd /var/www/html/
                mv /var/www/html/index.html /var/www/html/index_APACHE.html
                cp -a /opt/HBMonv2/html/. /var/www/html/
if [ -e info.php ]
then
        echo "------------------------------------------------------------------------------------"
        echo "It looks like the dashboard installed correctly. The installation will now proceed. "
        echo "------------------------------------------------------------------------------------"
        else
        echo "-----------------------------------------------------------------------------------------------"
        echo "I dont see the dashboard installed! Please check your configuration and try again. Exiting....."
        echo "-----------------------------------------------------------------------------------------------"
        exit 0
fi
echo "Done."

echo "Install crontab..."
cat << EOF > /etc/cron.daily/lastheard
#!/bin/bash
mv /opt/HBMonv2/log/lastheard.log /opt/HBMonv2/log/lastheard.log.save
/usr/bin/tail -150 /opt/HBMonv2/log/lastheard.log.save > /opt/HBMonv2/log/lastheard.log
mv /opt/HBMonv2/log/lastheard.log /opt/HBMonv2/log/lastheard.log.save
/usr/bin/tail -150 /opt/HBMonv2/log/lastheard.log.save > /opt/HBMonv2/log/lastheard.log
EOF
chmod 755 /etc/cron.daily/lastheard

sleep 2
echo "------------------------------------------------------------------------------"
echo "Installing HBlink3 configuration dirs....."
echo "------------------------------------------------------------------------------"
sleep 2
         echo Restart docker...
         systemctl restart docker
         sleep 3

         echo Make config directory...
         mkdir -p /etc/hblink3
         chmod 0755 /etc/hblink3

         echo make json directory...
         mkdir -p /etc/hblink3/json/

         echo get json files...
         cd /etc/hblink3/json
         curl https://radioid.net/static/users.json -o subscriber_ids.json
         curl https://freestar.network/downloads/talkgroup_ids.json -o talkgroup_ids.json
         curl https://radioid.net/static/rptrs.json -o peer_ids.json
echo "Done"
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Installing HBlink3 configuration file....."
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
REPORT_INTERVAL: 30
REPORT_PORT: 4321
REPORT_CLIENTS: *

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
LOG_FILE: hblink.log
LOG_HANDLERS: file-timed,console-timed
LOG_LEVEL: INFO
LOG_NAME: HBlink

# DOWNLOAD AND IMPORT SUBSCRIBER, PEER and TGID ALIASES
# Ok, not the TGID, there's no master list I know of to download
# This is intended as a facility for other applcations built on top of
# HBlink to use, and will NOT be used in HBlink directly.
# STALE_DAYS is the number of days since the last download before we
# download again. Don't be an ass and change this to less than a few days.
[ALIASES]
TRY_DOWNLOAD: True
PATH: ./json/
PEER_FILE: peer_ids.json
SUBSCRIBER_FILE: subscriber_ids.json
TGID_FILE: talkgroup_ids.json
PEER_URL: https://radioid.net/static/rptrs.json
SUBSCRIBER_URL: https://radioid.net/static/users.json
STALE_DAYS: 28

# OPENBRIDGE INSTANCES - DUPLICATE SECTION FOR MULTIPLE CONNECTIONS
# OpenBridge is a protocol originally created by DMR+ for connection between an
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
ENABLED: False
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
PASSPHRASE: passw0rd
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
[Parrot]
MODE: PEER
ENABLED: False
LOOSE: True
EXPORT_AMBE: False
IP: 127.0.0.1
PORT: 54098
MASTER_IP: 127.0.0.1
MASTER_PORT: 54100
PASSPHRASE: passw0rd
CALLSIGN: ECHO
RADIO_ID: 9999
RX_FREQ: 434000000
TX_FREQ: 434000000
TX_POWER: 10
COLORCODE: 1
SLOTS: 2
LATITUDE: 33.0000
LONGITUDE: -84.0000
HEIGHT: 75
LOCATION: 
DESCRIPTION: 
URL:
SOFTWARE_ID: 20230806
PACKAGE_ID: MMDVM_HBlink3
GROUP_HANGTIME: 5
OPTIONS:
USE_ACL: False
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL

[REPEATER-1]
MODE: PEER
ENABLED: False
LOOSE: False
EXPORT_AMBE: False
IP: 
PORT: 54001
MASTER_IP: 172.16.1.1
MASTER_PORT: 54000
PASSPHRASE: homebrew
CALLSIGN: M1ABC
RADIO_ID: 2350000
RX_FREQ: 449000000
TX_FREQ: 444000000
TX_POWER: 25
COLORCODE: 1
SLOTS: 1
LATITUDE: 38.0000
LONGITUDE: -095.0000
HEIGHT: 75
LOCATION: United Kingdom
DESCRIPTION: This is a very cool repeater
URL: www.freestar.network
SOFTWARE_ID: 20230103
PACKAGE_ID: MMDVM_HBlink3
GROUP_HANGTIME: 5
OPTIONS:
USE_ACL: True
SUB_ACL: DENY:1
TGID_TS1_ACL: PERMIT:ALL
TGID_TS2_ACL: PERMIT:ALL

[XLX-1]
MODE: XLXPEER
ENABLED: False
LOOSE: True
EXPORT_AMBE: False
IP: 
PORT: 54002
MASTER_IP: 172.16.1.1
MASTER_PORT: 62030
PASSPHRASE: passw0rd
CALLSIGN: M1ABC
RADIO_ID: 2350000
RX_FREQ: 449000000
TX_FREQ: 444000000
TX_POWER: 25
COLORCODE: 1
SLOTS: 1
LATITUDE: 38.0000
LONGITUDE: -095.0000
HEIGHT: 75
LOCATION: United Kingdom
DESCRIPTION: This is a very cool repeater
URL: www.w1abc.org
SOFTWARE_ID: 20230103
PACKAGE_ID: MMDVM_HBlink3
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
This file is organized around the "Conference Bridges" that you wish to use. If you're a C-Bridge
person, think of these as "bridge groups". You might also liken them to a "reflector". If a particular
system is "ACTIVE" on a particular conference bridge, any traffid from that system will be sent
to any other system that is active on the bridge as well. This is not an "end to end" method, because
each system must independently be activated on the bridge.
The first level (e.g. "FREESTAR" or "CQ-UK" in the examples) is the name of the conference
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
    '9999 Parrot': [
            {'SYSTEM': 'MASTER-1',   'TS': 2, 'TGID': 9999, 'ACTIVE': True, 'TIMEOUT': 0, 'TO_TYPE': 'NONE',  'ON': [9999],  'OFF': [], 'RESET': []},
#            {'SYSTEM': 'Parrot',     'TS': 2, 'TGID': 9999, 'ACTIVE': True, 'TIMEOUT': 0, 'TO_TYPE': 'NONE',  'ON': [],      'OFF': [], 'RESET': []},
        ],
    'FREESTAR': [
            {'SYSTEM': 'MASTER-1',    'TS': 1, 'TGID': 325,    'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'ON',  'ON': [2,], 'OFF': [9,10], 'RESET': []},
#            {'SYSTEM': 'CLIENT-1',    'TS': 1, 'TGID': 325, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'ON',  'ON': [2,], 'OFF': [9,10], 'RESET': []},
        ],
     'CQ-UK': [
            {'SYSTEM': 'MASTER-1',    'TS': 1, 'TGID': 2351,   'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [3,], 'OFF': [8,10], 'RESET': []},
#            {'SYSTEM': 'CLIENT-2',    'TS': 1, 'TGID': 2351,   'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [3,], 'OFF': [8,10], 'RESET': []},
        ],
     'CHATTERBOX': [
            {'SYSTEM': 'MASTER-1',    'TS': 2, 'TGID': 2350, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [4,], 'OFF': [7,10], 'RESET': []},
#            {'SYSTEM': 'CLIENT-2',    'TS': 2, 'TGID': 2350, 'ACTIVE': True, 'TIMEOUT': 2, 'TO_TYPE': 'NONE', 'ON': [4,], 'OFF': [7,10], 'RESET': []},
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
echo "Set up logging....."
echo "------------------------------------------------------------------------------"
        mkdir -p /var/log/hblink
        touch /var/log/hblink/hblink.log
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Installing docker-compose YAML and set up to run the server....."
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
echo "Set up permissions....."
echo "------------------------------------------------------------------------------"
        chmod -R 755 /etc/hblink3
        chmod -R 777 /etc/hblink3/json
        chown -R 54000 /etc/hblink3
        chown -R 54000 /var/log/hblink
echo ""
echo ""
echo "------------------------------------------------------------------------------"
echo "Wake up the docker container and pull latest docker image from ShaYmez....."
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
echo "Finishing up.....        Cleaning up installation files.....     /opt/tmp....."
echo "------------------------------------------------------------------------------"
        rm -rf /opt/tmp
echo "Done."
sleep 2
echo ""
echo ""
echo "----------------------------------------------------------------------------------"
echo "The installation will now complete.... Please wait.... Starting docker engine....."
echo "----------------------------------------------------------------------------------"
sleep 5
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
figlet "HBMonV2"
echo ""
echo ""
clear
sleep 2
echo "HBlink First Time Setup....."
sleep 1
figlet "WhipTAIL'"
        hblink-initial-setup
sleep 1
echo "Done."
echo ""
echo ""
echo "*************************************************************************"
echo ""
echo "                 The HBlink3 Docker Install Is Complete!                 "
echo ""
echo "              ******* To Update run 'hblink-update *******               "
echo ""
echo "        Use 'docker container logs hblink' to check the status.          "
echo "                  logs are parked in /var/log/hblink.                    "
echo "  Just make sure this computer can be accessed over UDP specified port   "
echo "  You will need to edit your config and then run the following command   "
echo ""
echo "                    Type 'hblink-menu' for main menu                     "
echo "                Use the menu to edit your server / config                "
echo "        Refer to the official HBlink Repo for more documentation         "
echo "                 https://github.com/HBLink-org/hblink3                   "
echo ""
echo "             Check out the docker installer of HBlink3 here              "
echo "            https://github.com/ShaYmez/hblink3-docker-install            "
echo ""
echo "                      Your IP address is $LOCAL_IP                       "
echo ""
echo "               Your running on $ARC with Debian $VERSION                 "
echo ""           
echo "                     Thanks for using this script.                       "
echo "                 Copyright © 2024 Shane Daley - M0VUB                    "
echo "      More information can be found @ https://github.com/shaymez/        "
echo ""
echo "*************************************************************************"
echo ""
echo ""
sleep 1
echo "Thanks for using the HBlink Docker Installer!"
exit
