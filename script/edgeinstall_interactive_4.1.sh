#!/bin/bash
RELEASE="4.1" #Edge Version to Install this does get updated often
echo "---------ClearBlade Interactive Edge Installer v0.9.2---------"
echo "Edge Release: $RELEASE"

if [ "$EUID" -ne 0 ]
  then
    echo "---------Permissions Error---------"
    echo "STOPPING: Please run as root or sudo"
    echo "-----------------------------------"
  exit
fi

#---------Ensure your architecture is correct----------
MACHINE_ARCHITECTURE="$(uname -m)"
MACHINE_OS="$(uname)"
echo "Machine Architecture: $MACHINE_ARCHITECTURE"
if [ "$MACHINE_ARCHITECTURE" == "armv6l" ] ; then
  ARCHITECTURE="edge-linux-armv6.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "armv7l" ] ; then
  ARCHITECTURE="edge-linux-armv7.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "armv8" ] ; then
  ARCHITECTURE="edge-linux-arm64.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "i686" ] ||  [ "$MACHINE_TYPE" == "i386" ] ; then
  ARCHITECTURE="edge-linux-386.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "x86_64" ] && [ "$MACHINE_OS" == "Darwin" ] ; then
  ARCHITECTURE="edge-darwin-amd64.tar.gz"
elif [ "$MACHINE_ARCHITECTURE" == "x86_64" ] && [ "$MACHINE_OS" == "Linux" ] ; then
  ARCHITECTURE="edge-linux-amd64.tar.gz"
else
  echo "---------Unknown Architecture Error---------"
    echo "STOPPING: Validate Architecture of OS"
    echo "-----------------------------------"
  exit
fi


#---------Logging Info---------
LOGLEVEL="debug"
#read -p "Enter Edge Token: " EDGECOOKIE
#read -p "Enter Edge Name: " EDGEID
#read -p "Enter System Key: " PARENTSYSTEM
#read -p "Enter Platform FQDN: " PLATFORMFQDN

#----------CONFIGURATION SETTINGS FOR EDGE if non-ineractive
EDGECOOKIE="7I6FfDt7ca250cIU61Qk44726Tv2p79" #Cookie from Edge Config Screen
EDGEID="edge3" #Edge Name when Created in the system
PARENTSYSTEM="aab189b30bcaf7b4fdd991aff210" #System Key of the application to connect
PLATFORMFQDN="bd.clearblade.com" #FQDN Hostname to Connect

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/bin
DEPLOYMENTFOLDER="clearblade"
CBBINPATH=$BINPATH/$DEPLOYMENTFOLDER
EDGEDBPATH=$BINPATH/$DEPLOYMENTFOLDER
EDGEUSERDBNAME=edgeusers.db
EDGEDBNAME=edge.db
DISABLEPPROF=true

#---------Edge Version---------
EDGEBIN="$BINPATH/$DEPLOYMENTFOLDER/edge"
DATASTORE="-db=sqlite -sqlite-path=$EDGEDBPATH/$EDGEDBNAME -sqlite-path-users=$EDGEDBPATH/$EDGEUSERDBNAME" # or "-local"


#---------Systemd Configuration---------
SYSTEMDPATH="/lib/systemd/system"
SYSTEMDSERVICENAME="clearblade.service"
SERVICENAME="ClearBlade Edge Service"


echo ---------------------1. Installing Prereqs---------------------
#---------Pre Reqs-------------------
apt-get update && time
apt-get dist-upgrade -y
apt-get install curl -y

#---------Edge Configuration---------
echo ---------------------2. Edge Config---------------------
echo "EDGECOOKIE: $EDGECOOKIE"
echo "EDGEID: $EDGEID"
echo "PARENTSYSTEM: $PARENTSYSTEM"
echo "PLATFORMFQDN: $PLATFORMFQDN"
echo "EDGEBIN: $EDGEBIN"
echo "RELEASE: $RELEASE"
echo "DATASTORE: $DATASTORE"
#---------Ensure your architecture is correct----------
echo "ARCHITECTURE: $ARCHITECTURE"
#---------Logging Info---------
echo "LOGLEVEL: $LOGLEVEL"

#---------Systemd Configuration---------
echo "SYSTEMDPATH: $SYSTEMDPATH"
echo "SYSTEMDSERVICENAME: $SYSTEMDSERVICENAME"
echo "SERVICENAME: $SERVICENAME"

echo ---------------------3. Cleaning old systemd services and binaries---------------------
systemctl stop $SYSTEMDSERVICENAME
systemctl disable $SYSTEMDSERVICENAME
#pkill -x edge
rm $SYSTEMDPATH/$SYSTEMDSERVICENAME

rm -rf $SYSTEMDSERVICENAME
echo Deleting ClearBlade BIN Folder
rm -rf /usr/bin/clearblade
systemctl daemon-reload

echo ---------------------4. Creating File Structure---------------------
mkdir $BINPATH #Just in case bin doesn't exist in /usr/bin
echo $CBBINPATH
mkdir $CBBINPATH
touch $EDGEDBPATH/$EDGEDBNAME
chmod 664 $EDGEDBPATH/$EDGEDBNAME 
touch $EDGEDBPATH/$EDGEUSERDBNAME
chmod 664 $EDGEDBPATH/$EDGEUSERDBNAME

echo ---------------------5. Downloading Edge---------------------
echo "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE"
curl -#SL -L "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE" -o /tmp/$ARCHITECTURE

echo ---------------------6. Installing Edge---------------------
tar xzvf /tmp/$ARCHITECTURE
ln -f "edge-$RELEASE" "$EDGEBIN"
chmod 774 "$EDGEBIN"
rm /tmp/$ARCHITECTURE

echo ---------------------7. Creating clearblade service---------------------

cat >$SYSTEMDSERVICENAME <<EOF
[Unit]
Description=$SERVICENAME Version: $RELEASE
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$CBBINPATH
ExecStart=$EDGEBIN -log-level=$LOGLEVEL -novi-ip=$PLATFORMFQDN -parent-system=$PARENTSYSTEM -edge-ip=localhost -edge-id=$EDGEID -edge-cookie=$EDGECOOKIE $DATASTORE -disable-pprof=$DISABLEPPROF
Restart=on-abort
TimeoutSec=30
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=ClearBladeEdge

[Install]
WantedBy=multi-user.target

EOF

echo ---------------------8. Placing service in systemd folder---------------------
mv "$SYSTEMDSERVICENAME" "$SYSTEMDPATH"

# echo "---Setting Startup Options"
systemctl daemon-reload
systemctl enable $SYSTEMDSERVICENAME
systemctl start $SYSTEMDSERVICENAME

echo ---------------------9. Waiting for Startup ---------------------
sleep 30 &
PID=$!
i=1
sp="/-\|"
echo -n ' '
while [ -d /proc/$PID ]
do
  printf "\b${sp:i++%${#sp}:1}"
done


echo "Run ----'systemctl status $SYSTEMDSERVICENAME'------for status"
systemctl status $SYSTEMDSERVICENAME
echo pgrep edge
