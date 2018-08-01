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
echo 
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


read -p "Enter Edge Token: " EDGECOOKIE
read -p "Enter Edge Name: " EDGEID
read -p "Enter System Key: " PARENTSYSTEM
read -p "Enter Platform FQDN: " PLATFORMFQDN

#----------CONFIGURATION SETTINGS FOR EDGE if non-ineractive
#EDGECOOKIE="" #Cookie from Edge Config Screen
#EDGEID="" #Edge Name when Created in the system
#PARENTSYSTEM="" #System Key of the application to connect
#PLATFORMFQDN="" #FQDN Hostname to Connect

#----------FILESYSTEM SETTINGS FOR EDGE
BINPATH=/usr/bin
VARPATH=/var/lib
CBBINPATH=$BINPATH/clearblade
EDGEDBPATH=$BINPATH/clearblade
EDGEUSERSDBPATH=$BINPATH/clearblade
EDGEUSERDBNAME=edgeusers.db
EDGEDBNAME=edge.db
DISABLEPPROF=true

#---------Edge Version---------
EDGEBIN="$BINPATH/clearblade/edge"
DATASTORE="-db=sqlite -sqlite-path=$EDGEDBPATH/$EDGEDBNAME -sqlite-path-users=$EDGEUSERSDBPATH/$EDGEUSERDBNAME" # or "-local"

#---------Logging Info---------
LOGLEVEL="info"
#---------Systemd Configuration---------
INITDPATH="/etc/init.d/"
INITDSERVICENAME="clearblade"
INITDSERVICE=$INITDPATH$INITDSERVICENAME
SERVICENAME="ClearBlade Edge Service"

#---------Edge Configuration---------
echo ---------------------3. Edge Config---------------------
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

echo ---------------------1. Cleaning old systemd services and binaries---------------------
$CBBINPATH stop
rm $CBBINPATH
rm -rf /var/lib/clearblade
rm "$EDGEBIN"

echo ---------------------4. Creating File Structure---------------------
mkdir $BINPATH #Just in case bin doesn't exist in /usr/local
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

echo ---------------------7. Creating clearblade service---------------------

cat >$INITDSERVICE <<EOF
#!/bin/sh
### BEGIN INIT INFO
# Provides:
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start daemon at boot time
# Description:       Enable service provided by daemon.
### END INIT INFO
name="edge"
dir=$CBBINPATH
cmd="./$name -novi-ip=$PLATFORMFQDN -parent-system=$PARENTSYSTEM -edge-ip=localhost -edge-id=$EDGEID -edge-cookie=$EDGECOOKIE -db=sqlite -sqlite-path=/var/lib/clearblade/edge.db -sqlite-path-users=/var/lib/clearblade/edgeusers.db"
user=""

stdout_log="/var/log/$name.log"
stderr_log="/var/log/$name.err"

is_running() {
    pgrep $name > /dev/null 2>&1
}

case "$1" in
    start)
    if is_running; then
        echo "Already started"
    else
        echo "Starting $name"
        cd "$dir"
        if [ -z "$user" ]; then
            $cmd >> "$stdout_log" 2>> "$stderr_log" &
        else
            $cmd >> "$stdout_log" 2>> "$stderr_log" &
        fi
        if ! is_running; then
            echo "Unable to start, see $stdout_log and $stderr_log"
            exit 1
        fi
    fi
    ;;
    stop)
    if is_running; then
        echo -n "Stopping $name.."
        kill $(pgrep $name)
        for i in 1 2 3 4 5 6 7 8 9 10
        # for i in 'seq 10'
        do
            if ! is_running; then
                break
            fi

            echo -n "."
            sleep 1
        done
        echo

        if is_running; then
            echo "Not stopped; may still be shutting down or shutdown may have failed"
            exit 1
        else
            echo "Stopped"
        fi
    else
        echo "Not running"
    fi
    ;;
    restart)
    $0 stop
    if is_running; then
        echo "Unable to stop, will not attempt to start"
        exit 1
    fi
    $0 start
    ;;
    status)
    if is_running; then
        echo "Running $(pgrep $name)"
    else
        echo "Stopped"
        exit 1
    fi
    ;;
    *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0

EOF


# echo "---Setting Startup Options"
update-rc.d $INITDSERVICE defaults
$INITDSERVICE start

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

$INITDSERVICE status

echo "Run ----'$INITDSERVICE status'------for status"





