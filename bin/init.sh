#! /bin/bash
#
# Dancer application startup script.
#
# Copyright (C) 2011-2014 Stefan Hornburg (Racke) <racke@linuxia.de>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin St, Fifth Floor, Boston,
# MA  02110-1301  USA.
#

. /lib/lsb/init-functions

# check for a dancefloor
if [ ! -f bin/app.pl ]; then
    echo "No dancefloor found, looked for bin/app.pl."
    exit 1;
fi

# now we can derive application name
if [ -z "$DANCER_APPDIR" ]; then
    DANCER_APPDIR=$(pwd)
fi

if [ ! -d $DANCER_APPDIR ]; then
    echo "Dancefloor $DANCER_APPDIR does not exist"
    exit 1
fi

if [ -z "$DANCER_APP" ]; then
    DANCER_APP=$(basename $DANCER_APPDIR)
fi

# directory for PID files
if [ -z "$DANCER_RUNDIR" ]; then
    DANCER_RUNDIR="$DANCER_APPDIR/run"
fi

if [ ! -d $DANCER_RUNDIR ]; then
    mkdir $DANCER_RUNDIR
fi

DANCER_PIDFILE="$DANCER_RUNDIR/$DANCER_APP.pid"

# environment
if [ -z "$DANCER_ENVIRONMENT" ]; then
    if [ -f "$DANCER_RUNDIR/$DANCER_APP.environment" ]; then
	DANCER_ENVIRONMENT=$(cat "$DANCER_RUNDIR/$DANCER_APP.environment")
    else
	DANCER_ENVIRONMENT="production"
    fi
fi

# host
if [ -z "$DANCER_HOST" ]; then
    if [ -f "$DANCER_RUNDIR/$DANCER_APP.host" ]; then
	DANCER_HOST=$(cat "$DANCER_RUNDIR/$DANCER_APP.host")
    else
	DANCER_HOST="127.0.0.1"
    fi
fi

# port 
if [ -z "$DANCER_PORT" ]; then
    if [ -f "$DANCER_RUNDIR/$DANCER_APP.port" ]; then
	DANCER_PORT=$(cat "$DANCER_RUNDIR/$DANCER_APP.port")
    else
	DANCER_PORT="5000"
    fi
fi

# path
if [ -f "$DANCER_RUNDIR/$DANCER_APP.path" ]; then
    DANCER_PATH="--path="$(cat "$DANCER_RUNDIR/$DANCER_APP.path")
fi

# workers
if [ -z "$DANCER_WORKERS" ]; then
    if [ -f "$DANCER_RUNDIR/$DANCER_APP.workers" ]; then
	    DANCER_WORKERS=$(cat "$DANCER_RUNDIR/$DANCER_APP.workers")
    elif [ "$DANCER_ENVIRONMENT" != "production" ]; then
        DANCER_WORKERS="2"
    else 
        DANCER_WORKERS="5"
    fi
fi


if [ -f "$DANCER_RUNDIR/$DANCER_APP.maxrequests" ]; then
    DANCER_MAX_REQUEST_PER_CHILD=$(cat "$DANCER_RUNDIR/$DANCER_APP.maxrequests")
else
    DANCER_MAX_REQUEST_PER_CHILD=1000
fi

DANCER_CMD=$(which plackup)

DANCER_CMDOPTS="-E $DANCER_ENVIRONMENT $DANCER_PATH -s Starman --workers=$DANCER_WORKERS --max-requests $DANCER_MAX_REQUEST_PER_CHILD --pid $DANCER_PIDFILE -o $DANCER_HOST -p $DANCER_PORT -a bin/app.pl -D"

check_running() {
    [ -s $DANCER_PIDFILE ] && kill -0 $(cat $DANCER_PIDFILE) >/dev/null 2>&1
}

check_compile() {
    # preserve error message from compile check
    APP_ERROR=$(cd $DANCER_APPDIR; perl -Ilib -M$DANCER_APP -ce1 2>&1)

    if [ -z "$APP_ERROR" ]; then
	return 0
    else
	return 1
    fi
}

check_plack_handler() {
    if `perl -MPlack::Handler::Starman -e ''`; then
	return 1
    else 
	return 0
    fi
}

_start() {
    /sbin/start-stop-daemon --start --chdir $DANCER_APPDIR --exec $DANCER_CMD --pidfile $DANCER_PIDFILE -- $DANCER_CMDOPTS

    if check_running; then
	return 0
    fi

    return 1
}

start() {
    log_daemon_msg "Joining dancefloor $DANCER_HOST:$DANCER_PORT with $DANCER_WORKERS dancers" "$DANCER_APP"

    if check_plack_handler; then
	log_failure_msg "Plack handler for Starman not available."
	log_end_msg 1
	exit 1
    fi

    if check_running; then
        log_progress_msg "already running"
        log_end_msg 0
        exit 0
    fi

    rm -f $DANCER_PIDFILE 2>/dev/null

    _start
    log_end_msg $?
    return $?
}

stop() {
    log_daemon_msg "Leaving dancefloor" "$DANCER_APP"
    /sbin/start-stop-daemon --stop --oknodo --pidfile $DANCER_PIDFILE
    log_end_msg $?
    return $?
}

restart() {
    log_daemon_msg "Spin on the dancefloor $DANCER_HOST:$DANCER_PORT with $DANCER_WORKERS dancers" "$DANCER_APP"

    if check_compile; then
        log_action_msg "$APP_ERROR"
        log_end_msg 1
        exit 1
    fi

    /sbin/start-stop-daemon --stop --oknodo --pidfile $DANCER_PIDFILE
    _start
    log_end_msg $?
    return $?
}


# See how we were called.
case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart|force-reload)
        restart
    ;;
    *)
        echo "Usage: $0 {start|stop|restart}"
        exit 1
esac
exit $?
