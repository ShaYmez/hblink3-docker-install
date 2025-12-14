#!/bin/bash
# Docker version alpine-3.18
# Version 1.5.0 (13122025) hblink3-docker-installer
# Docker upstream repo version 2.0.2
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
# A tool to install HBlink3 Docker with Debian 11, 12, and 13 support.
# This essentially is a HBlink3 server fully installed with dashboard ready to go.
# Step 1: Install Debian 11, 12, or 13 (Trixie) and make sure it has internet and is up to date.
# Step 2: Run this script on the computer.
# Step 3: Reboot after installation.
# This is a docker version and you can use the following commands to control / maintain your server
# cd /etc/hblink3
# docker compose up -d (starts the hblink3 docker container) - Note: uses Docker Compose v2
# docker compose down (shuts down the hblink container and stops the service)
# docker compose pull (updates the container to the latest docker image)
# For backward compatibility, docker-compose (with hyphen) is also supported via a wrapper script
# systemctl |stop|start|restart|status hbmon (controls the HBMonv2 dash service)
# logs can be found in var/log/hblink or docker command "docker container logs hblink"
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
  echo "This script is only tested in Debian 11, 12 & 13 (Trixie)."
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
        # For Debian 12+, add python3-venv to dependencies (PEP 668 compliance)
        if [ $version -ge 12 ]; then
                apt-get install -y $DEP python3-venv
        else
                apt-get install -y $DEP
        fi
        sleep 2
        
        # Remove old Docker versions if present
        echo "Removing old Docker versions if present..."
        apt-get remove docker docker-engine docker.io containerd runc docker-compose 2>/dev/null || true
        
        # Add Docker GPG key
        echo "Adding Docker GPG key..."
        curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        if [ ! -f /usr/share/keyrings/docker-archive-keyring.gpg ]; then
                echo "ERROR: Failed to download Docker GPG key"
                exit 1
        fi
        
        # Add Docker repository
        echo "Adding Docker repository..."
        echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine from official Docker repositories
        echo "Installing Docker Engine from official Docker repositories..."
        apt-get update
        if ! apt-get install -y docker-ce docker-ce-cli containerd.io; then
                echo "ERROR: Failed to install Docker Engine"
                echo "Please check your internet connection and Debian version compatibility"
                exit 1
        fi
        
        # Verify Docker is installed
        if ! command -v docker &> /dev/null; then
                echo "ERROR: Docker installation failed - docker command not found"
                exit 1
        fi
        
        # Install Docker Compose v2 plugin from official Docker repositories
        echo "Installing Docker Compose v2 plugin from official Docker repositories..."
        if ! apt-get install -y docker-compose-plugin; then
                echo "ERROR: Failed to install docker-compose-plugin from Docker repositories"
                echo "This installer only supports Docker Compose v2"
                exit 1
        fi
        
        # Verify Docker Compose v2 is installed
        if ! docker compose version &> /dev/null; then
                echo "ERROR: Docker Compose v2 installation failed - 'docker compose' command not working"
                exit 1
        fi
        
        # Create wrapper script for backward compatibility with docker-compose command
        # This allows existing scripts using 'docker-compose' to work with 'docker compose'
        echo "Creating docker-compose wrapper for backward compatibility..."
        if [ ! -f /usr/local/bin/docker-compose ]; then
                if cat > /usr/local/bin/docker-compose << 'EOF'
#!/bin/sh
# Wrapper script to provide docker-compose command using docker compose plugin
exec docker compose "$@"
EOF
                then
                        chmod +x /usr/local/bin/docker-compose
                        echo "docker-compose wrapper created successfully"
                else
                        echo "ERROR: Failed to create docker-compose wrapper script"
                        exit 1
                fi
        else
                echo "docker-compose command already exists at /usr/local/bin/docker-compose"
        fi
        
        # Verify the wrapper works
        if ! /usr/local/bin/docker-compose version &> /dev/null; then
                echo "ERROR: docker-compose wrapper verification failed"
                exit 1
        fi
        
        # Enable and start Docker
        echo "Enabling and starting Docker service..."
        systemctl enable docker
        systemctl start docker
        
        # Verify Docker service is running
        if ! systemctl is-active --quiet docker; then
                echo "ERROR: Docker service failed to start"
                exit 1
        fi
        
        figlet "docker.io"
        
        echo "Set userland-proxy to false..."
        echo '{ "userland-proxy": false}' > /etc/docker/daemon.json
        systemctl restart docker
        sleep 2
}

        if [ $VERSION = 11 ] || [ $VERSION = 12 ] || [ $VERSION = 13 ]; then
                echo "Installing for Debian $VERSION with Docker Compose v2..."
                install_docker_and_dependencies $VERSION
        elif [ $VERSION = 10 ]; then
                echo "ERROR: Debian 10 is no longer supported by this installer"
                echo "This installer now requires Debian 11, 12, or 13 for Docker Compose v2 support"
                echo "Please upgrade your system to Debian 11 or later"
                exit 1
        else
                echo "-------------------------------------------------------------------------------------------"
                echo "Operating system not supported! Please check you are running Debian 11, 12, or 13. Exiting....."
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
                # For Debian 12+, use virtual environment (PEP 668 compliant)
                echo "Installing Python packages for Debian $VERSION: $args"
                if [ -z "$VIRTUAL_ENV" ]; then
                        echo "ERROR: Virtual environment not activated"
                        return 1
                fi
                if pip3 install $args; then
                        echo "Successfully installed: $args"
                        return 0
                else
                        echo "ERROR: Failed to install: $args"
                        return 1
                fi
        else
                # For Debian 11, use standard pip installation (pre-PEP 668)
                echo "Installing Python packages for Debian $VERSION: $args"
                if pip3 install $args; then
                        echo "Successfully installed: $args"
                        return 0
                else
                        echo "ERROR: Failed to install: $args"
                        return 1
                fi
        fi
}

echo "Installing Python dependencies..."
cd $HBMONDIR

# For Debian 12+, create and use a virtual environment (modern PEP 668 compliant approach)
if [ $VERSION -ge 12 ]; then
        echo "Creating Python virtual environment for Debian $VERSION..."
        
        # Create virtual environment
        if [ ! -d "$HBMONDIR/venv" ]; then
                python3 -m venv "$HBMONDIR/venv" || { echo "ERROR: Failed to create virtual environment"; exit 1; }
                echo "Virtual environment created successfully at $HBMONDIR/venv"
        else
                echo "Virtual environment already exists at $HBMONDIR/venv"
        fi
        
        # Activate virtual environment
        source "$HBMONDIR/venv/bin/activate" || { echo "ERROR: Failed to activate virtual environment"; exit 1; }
        # Verify activation by checking VIRTUAL_ENV is set
        if [ -z "$VIRTUAL_ENV" ]; then
                echo "ERROR: Virtual environment activation failed - VIRTUAL_ENV not set"
                exit 1
        fi
        echo "Virtual environment activated"
        
        # Upgrade pip in the virtual environment
        if ! pip3 install --upgrade pip; then
                echo "WARNING: Failed to upgrade pip in virtual environment, continuing with existing version..."
        fi
fi

# Install setuptools and wheel first
if ! pip_install setuptools wheel; then
        echo "ERROR: Failed to install setuptools and wheel"
        echo "Please check your internet connection and Python installation"
        exit 1
fi

# Check if requirements.txt exists before trying to install
if [ -f requirements.txt ]; then
        if ! pip_install -r requirements.txt; then
                echo "ERROR: Failed to install packages from requirements.txt"
                echo "This may be due to network issues or missing system dependencies"
                exit 1
        fi
else
        echo "WARNING: requirements.txt not found in $HBMONDIR"
        echo "Continuing installation without requirements.txt dependencies..."
fi

# Install attrs with --force flag (note: --force is deprecated, using --force-reinstall)
if ! pip_install attrs --force-reinstall; then
        echo "WARNING: Failed to install attrs with --force-reinstall, trying without force..."
        if ! pip_install attrs; then
                echo "ERROR: Failed to install attrs package"
                exit 1
        fi
fi

echo Install /opt/HBMonv2/config.py ...
cat << EOF > /opt/HBMonv2/config.py
###############################################################################
#                    HBMonv2 Configuration File Example
#         Copyright (C) 2013-2018 Cortney T. Buffington, N0MJS n0mjs@me.com
#         Copyright (C) 2025 Shane aka, ShaYmez <shane@freestar.network>
###############################################################################

# ---- FEATURE TOGGLES --------------------------------------------------------
CONFIG_INC      = True    # Include HBlink stats
HOMEBREW_INC    = True    # Display Homebrew Peers status
LASTHEARD_INC   = True    # Display lastheard table on main page
BRIDGES_INC     = False   # Display Bridge status and button
EMPTY_MASTERS   = False   # Enable (True) or Disable (False) empty masters in status

# ---- CONNECTION SETTINGS ----------------------------------------------------
HBLINK_IP       = '127.0.0.1'    # HBlink's IP Address
HBLINK_PORT     = 4321           # HBlink's TCP reporting socket
FREQUENCY       = 10             # Frequency (secs) to push updates to web clients
CLIENT_TIMEOUT  = 0              # Timeout clients after N secs (0=disable)

# ---- NETWORK FILTERING ------------------------------------------------------
# To hide in lastheard: provide comma-separated NETWORK IDs
# Example: "260210,260211,260212"
OPB_FILTER      = ""

# ---- ALIAS FILES AND PATHS --------------------------------------------------
PATH            = './'                           # Base path (MUST END IN '/')
PEER_FILE       = 'peer_ids.json'                # Auto-download
SUBSCRIBER_FILE = 'subscriber_ids.json'          # Auto-download
TGID_FILE       = 'talkgroup_ids.json'           # User provided
LOCAL_SUB_FILE  = 'local_subscriber_ids.json'    # Optional, user provided ('' if not used)
LOCAL_PEER_FILE = 'local_peer_ids.json'          # Optional, user provided ('' if not used)
LOCAL_TGID_FILE = 'local_talkgroup_ids.json'     # Optional, user provided ('' if not used)
FILE_RELOAD     = 14                             # Days before reloading MARC files

# ---- ALIAS DOWNLOAD URLS ----------------------------------------------------
PEER_URL        = 'https://radioid.net/static/rptrs.json'
SUBSCRIBER_URL  = 'https://radioid.net/static/users.json'

# ---- LOGGING SETTINGS -------------------------------------------------------
LOG_PATH        = './log/'               # MUST END IN '/'
LOG_NAME        = 'hbmon.log'

###############################################################################
#                        END OF CONFIGURATION FILE
###############################################################################

EOF
                cp utils/hbmon.service /lib/systemd/system/
                
                # For Debian 12+, update the service file to use virtual environment
                if [ $VERSION -ge 12 ]; then
                        echo "Updating hbmon.service to use virtual environment..."
                        # Update ExecStart to use venv Python (only if not already using venv)
                        if ! grep -q "$HBMONDIR/venv/bin/python3" /lib/systemd/system/hbmon.service; then
                                # Replace common Python interpreter paths with venv path
                                sed -i "s|ExecStart=/usr/bin/python3|ExecStart=$HBMONDIR/venv/bin/python3|g" /lib/systemd/system/hbmon.service
                                sed -i "s|ExecStart=python3 |ExecStart=$HBMONDIR/venv/bin/python3 |g" /lib/systemd/system/hbmon.service
                                
                                # Verify the service file was updated correctly
                                if grep -q "ExecStart=$HBMONDIR/venv/bin/python3" /lib/systemd/system/hbmon.service; then
                                        echo "Service file updated to use virtual environment"
                                else
                                        echo "WARNING: Service file update may not have completed correctly"
                                        echo "Please manually verify /lib/systemd/system/hbmon.service uses $HBMONDIR/venv/bin/python3"
                                fi
                        else
                                echo "Service file already configured to use virtual environment"
                        fi
                fi
                
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
sleep 2
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
echo "------------------------------------------------------------------------------"
echo "                          Installed Versions                                  "
echo "------------------------------------------------------------------------------"
echo "Docker version:"
docker --version
echo ""
echo "Docker Compose version:"
docker compose version
echo ""
echo "Note: This installation uses Docker Compose v2 (docker compose command)"
echo "      The legacy docker-compose v1 is not supported"
echo "------------------------------------------------------------------------------"
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
