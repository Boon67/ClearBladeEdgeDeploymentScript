#!/bin/bash
echo "---------ClearBlade Interactive Edge Installer v0.9.1---------"
RELEASE="3.21" #Edge Version to Install this does get updated often
echo "Edge Release: $RELEASE" 

if [ "$EUID" -ne 0 ]
  then 
    echo "---------Permissions Error---------"
    echo "STOPPING: Please run as root or sudo"
    echo "-----------------------------------"
  exit
fi

read -p "Enter Edge Token: " EDGECOOKIE
read -p "Enter Edge Name: " EDGEID
read -p "Enter System Key: " PARENTSYSTEM
read -p "Enter Platform URL: " PLATFORMFQDN

#----------CONFIGURATION SETTINGS FOR EDGE if non-ineractive
#EDGECOOKIE="" #Cookie from Edge Config Screen
#EDGEID="" #Edge Name when Created in the system
#PARENTSYSTEM="" #System Key of the application to connect
#PLATFORMFQDN="" #FQDN Hostname to Connect

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/local/bin/clearblade
EDGEDBPATH=/var/lib/clearblade
EDGEUSERSDBPATH=/var/lib/clearblade
#---------Edge Version---------
EDGEBIN="/usr/local/bin/clearblade/edge"
DATASTORE="-db=sqlite -sqlite-path=$EDGEDBPATH/edge.db -sqlite-path-users=$EDGEUSERSDBPATH/edgeusers.db" # or "-local"

#---------Logging Info---------
LOGLEVEL="info"
#---------Systemd Configuration---------
SYSTEMDPATH="/lib/systemd/system"
SYSTEMDSERVICENAME="clearblade.service"
SERVICENAME="ClearBlade Edge Service"
NETWORKSERVICENAME="clearbladenetwork.service"

#---------Ensure your architecture is correct----------
MACHINE_ARCHITECTURE="$(uname -m)"
MACHINE_OS="$(uname)"
echo 
if [ "$MACHINE_ARCHITECTURE" == "armv7l" ] ; then
  ARCHITECTURE="edge-linux-arm.tar.gz"
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

echo ---------------------1. Installing Prereqs---------------------
#---------Pre Reqs-------------------
apt-get update && time -y
apt-get dist-upgrade -y
if ! curl_loc="$(type -p "curl")" || [ -z "$curl_loc"]; then
 apt-get install curl -y
fi

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
rm $SYSTEMDPATH/$NETWORKSERVICENAME

systemctl stop $SYSTEMDSERVICENAME
systemctl disable $SYSTEMDSERVICENAME
rm $SYSTEMDPATH/$SYSTEMDSERVICENAME
rm -rf $SYSTEMDSERVICENAME
rm -rf /var/lib/clearblade
rm "$EDGEBIN"
systemctl daemon-reload

echo ---------------------4. Creating File Structure---------------------
mkdir $BINPATH
mkdir $EDGEDBPATH
mkdir $EDGEUSERSDBPATH

echo ---------------------5. Downloading Edge---------------------
echo "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE"
curl -#SL -L "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE" -o /tmp/$ARCHITECTURE

echo ---------------------6. Installing Edge---------------------
tar xzvf /tmp/$ARCHITECTURE
ln -f "edge-$RELEASE" "$EDGEBIN"
chmod +x "$EDGEBIN"

rm /tmp/$ARCHITECTURE

echo ---------------------7. Creating systemd network service---------------------
#Create a systemd service
echo "------Configuring Service"
cat >$NETWORKSERVICENAME <<EOF
[Unit]
Description=Ping a server on the internet until it becomes reachable

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'while ! ping -c1 $PLATFORMFQDN; do sleep 1; done'
TimeoutStartSec=60s

EOF
echo ---------------------8. Creating clearblade service---------------------

cat >$SYSTEMDSERVICENAME <<EOF
[Unit]
Description=$SERVICENAME Version: $RELEASE
Requires=$NETWORKSERVICENAME
After=$NETWORKSERVICENAME 

[Service]
Type=simple
ExecStart=$EDGEBIN -log-level=$LOGLEVEL -novi-ip=$PLATFORMFQDN -parent-system=$PARENTSYSTEM -edge-ip=localhost -edge-id=$EDGEID -edge-cookie=$EDGECOOKIE $DATASTORE
Restart=on-abort
TimeoutSec=30
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

[Install]
WantedBy=multi-user.target

EOF

echo ---------------------10. Placing service in systemd folder---------------------

mv "$NETWORKSERVICENAME" "$SYSTEMDPATH"
mv "$SYSTEMDSERVICENAME" "$SYSTEMDPATH"

# echo "---Setting Startup Options"
systemctl daemon-reload
systemctl enable $SYSTEMDSERVICENAME
systemctl start $SYSTEMDSERVICENAME

echo ---------------------Waiting for Startup ---------------------
sleep 10 &
PID=$!
i=1
sp="/-\|"
echo -n ' '
while [ -d /proc/$PID ]
do
  printf "\b${sp:i++%${#sp}:1}"
done

systemctl status $SYSTEMDSERVICENAME

echo "Run ----'systemctl status $SYSTEMDSERVICENAME'------for status"





