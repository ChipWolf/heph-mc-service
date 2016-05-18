#!/bin/bash
# version 0.2.0 2015-05-18

# VARS
USERNAME="minecraft"
SERVICE='minecraft_server.jar'
MCPATH="/home/$USERNAME/minecraft"
BACKUPPATH="/home/$USERNAME/backup"
CHECKSERVER="/home/$USERNAME/checksrv"
CRASHLOG_DB_PATH='/home/$USERNAME/crashdb'
JAVA_HOME="/usr/bin/java"
MEMORY_OPTS="-Xmx4G -Xms4G"
JAVA_OPTIONS=""
INVOCATION="${JAVA_HOME}/bin/java ${MEMORY_OPTS} ${JAVA_OPTIONS} -jar $SERVICE nogui"
BACKUPARCHIVEPATH=$BACKUPPATH/archive
BACKUPDIR=$(date +%H%M_b%Y_%N)
PORT=$(grep server-port $MCPATH/server.properties | cut -d '=' -f 2)
if [ -z "$PORT" ];then PORT=25565;fi
# END VARS

if [ $(whoami) != $USERNAME ];then su $USERNAME -l -c "$(readlink -f $0) $*";exit $?;fi
heph_startmonitor() { if [ -z $CHECKSERVER ];then echo "MONITOR: ACTIVE";/usr/bin/daemon --name=minecraft_checkserver -- $JAVA_HOME/bin/java -cp $CHECKSERVER chksrv localhost $PORT;fi;}
heph_stopmonitor() { if [ -z $CHECKSERVER ];then /usr/bin/daemon --name=minecraft_checkserver --stop;fi;}
heph_dumpcrash() { if is_running;then cp $MCPATH/crash-reports/* $CRASHLOG_DB_PATH;mv $MCPATH/crash-reports/* $MCPATH/crash-reports.archive/;fi;}
heph_exec() { if is_running;then screen -p 0 -S $(cat $MCPATH/screen.name) -X stuff "$@$(printf \\r)";else echo "NOCOMMAND: $SERVICE NORUN";fi;}

is_running() {
	if [ ! -e $MCPATH/java.pid ];then return 1;fi
	pid=$(cat $MCPATH/java.pid);if [ -z $pid ];then return 1;fi
	ps -eo "%p" | grep "^\\s*$pid\\s*\$" > /dev/null
	return $?
}

heph_start() {
	if is_running; then
		echo "FAILSTART: $SERVICE RUNNING"
	else
		echo "$SERVICE START"
		
		cd $MCPATH
		screen -dmS heph$PORT $INVOCATION &
		
		for (( i=0; i < 10; i++ )); do
			screenpid=$(ps -eo '%p %a' | grep -v grep | grep -i screen | grep heph$PORT | awk '{print $1}')
			javapid=$(ps -eo '%P %p' | grep "^\\s*$screenpid " | awk '{print $2}')
			if [[ -n "$screenpid" && -n "$javapid" ]];then break;fi;sleep 1
		done
		
		if [[ -n "$screenpid" && -n "$javapid" ]]; then
			echo "$SERVICE RUNNING"
			echo "$javapid" > $MCPATH/java.pid
			echo "$screenpid.heph$PORT" > $MCPATH/screen.name
		else
			echo "FAILSTART: $SERVICE"
		fi
	fi
}

heph_saveoff() {
	if is_running; then
		echo "SUSPENDSAVE: $SERVICE RUNNING"
		heph_exec "say §k§9ch §r§cHiding §cPorn §cStash §r§k§9ip"
		heph_exec "say §a> §agoing §aread-only"
		heph_exec "save-off"
		heph_exec "save-all"
		sync
		sleep 10
	else
		echo "FAILSAVESUSPEND: $SERVICE NORUN"
	fi
}

heph_saveon() {
	if is_running; then
		echo "ENABLEDSAVE: $SERVICE RUNNING"
		heph_exec "save-on"
		heph_exec "say §k§9ch §r§cMom's §cGone §r§k§9ip"
		heph_exec "§a> §agoing §aread-write"
	else
		echo "FAILSAVERESUME: $SERVICE NORUN"
	fi
}

heph_kill() {
	pid=$(cat $MCPATH/java.pid)
	echo "TERM PID:$pid"
	kill $pid;for (( i=0;i < 10;i++ ));do is_running || break;sleep 1;done
	if is_running;then echo "FAILTERM: KILLING $SERVICE";kill -SIGKILL $pid;echo "$SERVICE K.O.";else echo "$SERVICE TERM";fi
}

heph_stop() {
	if is_running; then
		echo "STOPPING: $SERVICE RUNNING"
		heph_exec "say §k§9ch §cSelf-Destruct §cSequence §cStart §k§9ip"
		heph_exec "say §a> §ashutdown §at-minus §a± §a300s"
		sleep 240
		heph_exec "say §a> §ashutdown §at-minus §a± §a60s"
		sleep 30
		heph_exec "say §a> §ashutdown §at-minus §a± §a30s"
		heph_exec "save-all"
		sleep 20
		heph_exec "say §a> §ashutdown §at-minus §a± §a10s"
		sleep 5
		heph_exec "say §a> §ashutdown §at-minus §a± §a5s"
		sleep 1
		heph_exec "say §a> §ashutdown §at-minus §a± §a4s"
		sleep 1
		heph_exec "say §a> §ashutdown §at-minus §a± §a3s"
		sleep 1
		heph_exec "say §a> §ashutdown §at-minus §a± §a2s"
		heph_exec "stop"
		heph_exec "say §a> §ashutdown §at-minus §a± §a1s"
		for (( i=0;i < 20;i++ ));do is_running || break;sleep 1;done
	else
		echo "$SERVICE NORUN"
	fi
	
	if is_running;then echo "NOCLEAN: $SERVICE RUNNING";heph_kill;else echo "$SERVICE DOWN";fi
	rm $MCPATH/java.pid;rm $MCPATH/screen.name
}

heph_backup() {
	echo "BACKUP COMMENCE"
	[ -d "$BACKUPPATH/$BACKUPDIR" ] || mkdir -p "$BACKUPPATH/$BACKUPDIR"
	rdiff-backup $MCPATH "$BACKUPPATH/$BACKUPDIR"
	echo "BACKUP COMPLETE"
}

heph_thinoutbackup() {
	archivedate=$(date --date="3 days ago")
	echo "THINBACKUP since $archivedate"
	archivedateunix=$(date --date="$archivedate" +%s)
	archivesourcedir=$BACKUPPATH/$(date --date="$archivedate" +%b_%Y)
	archivesource=$archivesourcedir/rdiff-backup-data/increments.$(date --date="$archivedate" +%Y-%m-%dT%H):0*.dir
	archivesource=$(echo $archivesource)
	archivedest=$BACKUPARCHIVEPATH/$(date --date="$archivedate" +%H%M_b%Y_%N)
	if [[ ! -f $archivesource ]]; then
		echo "NOPE"
	else
		tempdir=$(mktemp -d)
		if [[ ! $tempdir =~ ^/tmp ]]; then
			echo "INVALID DIR $tempdir"
		else
			rdiff-backup $archivesource $tempdir
			rdiff-backup --current-time $archivedateunix $tempdir $archivedest
			rm -R "$tempdir"
			rdiff-backup --remove-older-than 3D --force $archivesourcedir
			echo "DONE"
		fi
	fi
}

case "$1" in
  start)
    if heph_start;then heph_startmonitor;fi
    ;;
  stop)
    heph_stopmonitor
    heph_stop
	heph_dumpcrash
    ;;
  restart)
    heph_stopmonitor
    heph_stop
    heph_dumpcrash
    if heph_start;then heph_startmonitor;fi
    ;;
  backup)
    heph_saveoff
    heph_backup
    heph_saveon
    heph_thinoutbackup
    ;;
  exec)
    shift
    heph_exec "$@"
    ;;
  dumpcrashlogs)
    heph_dumpcrash
    ;;
  status)
    if is_running;then echo "$SERVICE RUNNING";else echo "$SERVICE NORUN";fi
    ;;

  *)
  echo "Usage: $(readlink -f $0) {start|stop|restart|backup|exec|dumpcrashlogs|status}"
  exit 1
  ;;
esac

exit 0
