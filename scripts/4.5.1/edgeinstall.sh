#!/bin/bash
RELEASE="4.5.1" #Edge Version to Install this does get updated often
echo "---------ClearBlade Interactive Edge Installer v0.9.3---------"
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
read -p "Enter Edge Release Version: " RELEASE
read -p "Enter Edge Token: " EDGECOOKIE
read -p "Enter Edge Name: " EDGEID
read -p "Enter System Key: " PARENTSYSTEM
read -p "Enter Platform FQDN: " PLATFORMFQDN

#----------CONFIGURATION SETTINGS FOR EDGE if non-ineractive
RELEASE="4.5.1" #Edge Version
#EDGECOOKIE="<EDGETOKENREQUIRED>" #Cookie from Edge Config Screen
#EDGEID="<EDGEIDREQUIRED>" #Edge Name when Created in the system
#PARENTSYSTEM="<SYSTEMKEYREQUIRED>" #System Key of the application to connect
#PLATFORMFQDN="platform.clearblade.com" #FQDN Hostname to Connect

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/local/bin
EDGEDBPATH=/usr/local/bin #Only change if you want on a different path than the edge binary
USERDBPATH=/usr/local/bin #Only change if you want on a different path than the edge binary
CBBINPATH=$EDGEDBPATH/clearblade
EDGEDBPATH=$VARPATH/clearblade
EDGEUSERSDBPATH=$USERDBPATH/clearblade
EDGEUSERDBNAME=edgeusers.db
EDGEDBNAME=edge.db
DISABLEPPROF=true

#---------Edge Version---------
EDGEBIN="$BINPATH/clearblade/edge"
DATASTORE="-db=sqlite -sqlite-path=$EDGEDBPATH/$EDGEDBNAME -sqlite-path-users=$EDGEUSERSDBPATH/$EDGEUSERDBNAME" # or "-local"

#---------Logging Info---------
LOGLEVEL="info"
#---------Systemd Configuration---------
SYSTEMDPATH="/lib/systemd/system"
SYSTEMDSERVICENAME="clearblade.service"
SERVICENAME="ClearBlade Edge Service"


echo ---------------------1. Installing Prereqs---------------------
#---------Pre Reqs-------------------
#apt-get update && time 
#apt-get dist-upgrade -y
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

systemctl stop $SYSTEMDSERVICENAME
systemctl disable $SYSTEMDSERVICENAME
rm $SYSTEMDPATH/$SYSTEMDSERVICENAME
rm -rf $SYSTEMDSERVICENAME
rm -rf /var/lib/clearblade
rm "$EDGEBIN"
systemctl daemon-reload

echo ---------------------4. Creating File Structure---------------------
mkdir $BINPATH #Just in case bin doesn't exist in /usr/local
mkdir $CBBINPATH
mkdir $EDGEDBPATH
mkdir $EDGEUSERSDBPATH

echo ---------------------5. Downloading Edge---------------------
echo "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE"
curl -#SL -L "https://github.com/ClearBlade/Edge/releases/download/$RELEASE/$ARCHITECTURE" -o /tmp/$ARCHITECTURE

echo ---------------------6. Installing Edge---------------------
tar xzvf /tmp/$ARCHITECTURE
ln -f "edge" "$EDGEBIN"
chmod +x "$EDGEBIN"

rm /tmp/$ARCHITECTURE

echo ---------------------7. Creating clearblade service---------------------

cat >$SYSTEMDSERVICENAME <<EOF
[Unit]
Description=$SERVICENAME Version: $RELEASE

[Service]
Type=simple
WorkingDirectory=$CBBINPATH
ExecStart=$EDGEBIN -log-level=$LOGLEVEL -novi-ip=$PLATFORMFQDN -parent-system=$PARENTSYSTEM -edge-ip=localhost -edge-id=$EDGEID -edge-cookie=$EDGECOOKIE $DATASTORE -disable-pprof=$DISABLEPPROF 
Restart=on-abort
TimeoutSec=30
RestartSec=30
StartLimitInterval=350
StartLimitBurst=10

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

systemctl status $SYSTEMDSERVICENAME

echo "Run ----'systemctl status $SYSTEMDSERVICENAME'------for status"
