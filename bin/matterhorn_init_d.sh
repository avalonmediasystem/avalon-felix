#!/bin/sh
### BEGIN INIT INFO
# Provides:          opencast matterhorn
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: lecture recording and management system
### END INIT INFO
# /etc/init.d/matterhorn
#

set -e

##
# These variables are set in the configuration scripts.
##
#eg:  /opt/matterhorn
MATTERHORN=${MATTERHORN_HOME:-/opt/matterhorn}
#eg:  /opt/matterhorn/felix, or $MATTERHORN/felix
FELIX=${FELIX_HOME:-$MATTERHORN/felix}
#eg:  /opt/matterhorn/capture-agent, or $MATTERHORN/capture-agent
CA=${CA_DIR:-$MATTERHORN/capture-agent}
#eg:  Commonly opencast or matterhorn.  Can also be your normal user if you are testing.
MATTERHORN_USER=$USER
M2_REPOSITORY=${M2_REPO:-/home/$MATTERHORN_USER/.m2/repository}
#Enable this if this machine is a CA.  This will enable capture device autoconfiguration.
IS_CA=false

LOGDIR=$FELIX/logs

PATH=$PATH:$FELIX

##
# To enable the debugger on the vm, enable all of the following options
##

DEBUG_PORT="8000"
DEBUG_SUSPEND="n"
#DEBUG_OPTS="-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=$DEBUG_PORT,server=y,suspend=$DEBUG_SUSPEND"

##
# Only change the line below if you want to customize the server
##

FELIX_OPTS="-Dfelix.home=$FELIX"
FELIX_WORK="-Dfelix.work=$FELIX/work"
MAVEN_ARG="-DM2_REPO=$M2_REPOSITORY"
FELIX_FILEINSTALL_OPTS="-Dfelix.fileinstall.dir=$FELIX/load"
PAX_CONFMAN_OPTS="-Dbundles.configuration.location=$FELIX/conf"
PAX_LOGGING_OPTS="-Dorg.ops4j.pax.logging.DefaultServiceLog.level=WARN -Dopencast.logdir=$LOGDIR"
UTIL_LOGGING_OPTS="-Djava.util.logging.config.file=$FELIX/conf/services/java.util.logging.properties"
GRAPHICS_OPTS="-Djava.awt.headless=true -Dawt.toolkit=sun.awt.HeadlessToolkit"
JAVA_OPTS="-Xms1024m -Xmx1024m -XX:MaxPermSize=256m"

# The following lines are required to run Matterhorn as a service in Redhat.  
# These lines should remain commented out.  
# It is necessary to run "chkconfig matterhorn on" to enable matterhorn service management with Redhat.

#chkconfig: 2345 99 01 
#description: lecture recording and management system 

# If this computer is OS X and $DYLD_FALLBACK_LIBRARY_PATH environment variable
# is not defined, then set it to /opt/local/lib. This is required for the demo
# capture agent.  
unameResult=`uname`
if [ $unameResult = 'Darwin' ];
then 
 	if [ "$DYLD_FALLBACK_LIBRARY_PATH" = "" ];
	then
		export DYLD_FALLBACK_LIBRARY_PATH="/opt/local/lib";
	fi
fi

FELIX_CACHE="$FELIX/felix-cache"


###############################
### NO CHANGES NEEDED BELOW ###
###############################

 
case "$1" in
  start)
    echo -n "Starting Matterhorn as user $MATTERHORN_USER: " 
    if $IS_CA ; then
        $CA/device_config.sh
        if [ -d $CA/epiphan_driver -a -z "$(lsmod | grep vga2usb)" ]; then
                make -C $CA/epiphan_driver load
        fi
    fi

# check if felix is already running
    MATTERHORN_PID=`ps aux | awk '/felix.jar/ && !/awk/ {print $2}'`
    if [ ! -z "$MATTERHORN_PID" ]; then
      echo "OpenCast Matterhorn is already running"
      exit 1
    fi


# Make sure matterhorn bundles are reloaded
    if [ -d "$FELIX_CACHE" ]; then
      echo "Removing cached matterhorn bundles from $FELIX_CACHE"
      for bundle in `find "$FELIX_CACHE" -type f -name bundle.location | xargs grep --files-with-match -e "file:" | sed -e s/bundle.location// `; do
        rm -r $bundle
      done
    fi
    
    cd $FELIX

# starting felix

    su -c "java -Dgosh.args='--noshutdown -c noop=true' $DEBUG_OPTS $FELIX_OPTS $GRAPHICS_OPTS $TEMP_OPTS $FELIX_WORK $MAVEN_ARG $JAVA_OPTS $FELIX_FILEINSTALL_OPTS $PAX_CONFMAN_OPTS $PAX_LOGGING_OPTS $UTIL_LOGGING_OPTS $CXF_OPTS -jar $FELIX/bin/felix.jar $FELIX_CACHE 2>&1 > /dev/null &" $MATTERHORN_USER
    echo "done." 
    ;;    
  stop)
    echo -n "Stopping Matterhorn: " 
    MATTERHORN_PID=`ps aux | awk '/felix.jar/ && !/awk/ {print $2}'`
    if [ -z "$MATTERHORN_PID" ]; then
      echo "Matterhorn already stopped"
      exit 1
    fi

    kill $MATTERHORN_PID

    sleep 7

    MATTERHORN_PID=`ps aux | awk '/felix.jar/ && !/awk/ {print $2}'`
    if [ ! -z $MATTERHORN_PID ]; then
      echo "Hard killing since felix ($MATTERHORN_PID) seems unresponsive to regular kill"
    
      kill -9 $MATTERHORN_PID
    fi


    if $IS_CA ; then
        if [ -d $CA/epiphan_driver -a -z "$(lsmod | grep vga2usb)" ]; then
                make -C $CA/epiphan_driver unload
        fi
    fi

    echo "done."
    ;;
  restart)
    $0 stop
    $0 start
    ;;
  status)
    MATTERHORN_PID=`ps aux | awk '/felix.jar/ && !/awk/ {print $2}'`
    if [ -z "$MATTERHORN_PID" ]; then
      echo "Matterhorn is not running"
      exit 0
    else
      echo "OpenCast Matterhorn is running with PID $MATTERHORN_PID"
      exit 0
    fi   
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac

exit 0
