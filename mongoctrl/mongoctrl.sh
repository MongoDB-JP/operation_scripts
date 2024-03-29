#!/usr/bin/env bash
#----------------------------
# Usage
function usage {
    cat <<EOF
Usage:
   mongoctrl <operation>

Operations:
   help    : This message.
   start   : Start mongod
   stop    : Stop mongod

Examples:
   $ mongoctrl start
   $ mongoctrl stop
EOF
    exit $1;
}
#----------------------------
# Arguments
if [ "${MONGO_HOME}" = "" ]; then
    MONGO_HOME=`dirname $0`
fi
OP=$1
#----------------------------
# Host specialized
if [ "$MONGO_CONF" = "" ]; then
    MONGO_CONF=${MONGO_HOME}/conf/mongod.conf
fi
PIDFILE=`grep pidfilepath ${MONGO_CONF} | sed -e 's/^ *pidfilepath *= *//'`
MONGOD=${MONGO_HOME}/bin/mongod
MONGOD_IP=`grep bind_ip ${MONGO_CONF} | sed -e 's/^ *bind_ip *= *//' | tr -d [:space:] `
#MONGOD_IP=127.0.0.1
MONGOD_PORT=`grep port ${MONGO_CONF} | sed -e 's/^ *port *= *//'`
MONGO=${MONGO_HOME}/bin/mongo
MONGO_DATA=`grep dbpath ${MONGO_CONF} | sed -e 's/^ *dbpath *= *//'`
MONGO_LOCK=${MONGO_DATA}/mongod.lock
MONGODUMP=${MONGO_HOME}/bin/mongodump

#----------------------------
# Check
function check () {
    if [ -f ${PIDFILE} ]; then
        ps vp `cat ${PIDFILE}` | grep mongod > /dev/null 2>&1
        if [ $? = 0 ]; then
            cat ${PIDFILE} | xargs echo "mongod process running...  "
            return 0;
        fi
        cat ${PIDFILE} | xargs echo "mongod process not running...  "
    fi
    echo "mongod process not running...  "
    return 1;
}

#----------------------------
# Operation dispatcher. ( help /start / stop / rotate / status / locate )
case ${OP} in
    help)
        usage 0
        ;;
    start)
        check
        if [ $? = 0 ];then
            echo mongod already alived !
            exit 0;
        fi
	${MONGOD} --config ${MONGO_CONF} 
        exit $?
        ;;
    stop)
        check
        if [ $? = 1 ];then
            echo mongod not alived !
            exit 0;
        fi
	kill -15 `cat ${PIDFILE}`
	if [ $? != 0 ]; then
	    return 1;
	fi
        # wait 30 sec
	for i in {1..30}
	  do
	  check;
	  if [ $? = 1 ] ;then
	      exit 0;
	  fi
	  sleep 1;
	done
	echo "process cannot terminate ! so send kill -9 !! "
	kill  -9 `cat $PIDFILE`
        exit $?
        ;;
    rotate)
        check
        if [ $? = 1 ];then
            echo mongod not alived !
            exit 0;
        fi
	kill -SIGUSR1 `cat ${PIDFILE}`
        ;;
    backup)
        check
        if [ $? = 1 ];then
            echo mongod not alived !
            exit 0;
        fi
	DUMP_NAME=dump.`date +'%Y%m%d-%H%M%S'`
	DUMP_DIR=${MONGO_HOME}/backup/${DUMP_NAME}
	${MONGODUMP} --directoryperdb -o ${DUMP_DIR}
	mkdir -p ${MONGO_HOME}/backup/
	cd ${MONGO_HOME}/backup/
	tar czvf ${DUMP_NAME}.tar.gz ${DUMP_NAME}
	rm -rf ${DUMP_DIR}
        ;;
    status)
	${MONGO} ${MONGOD_IP}:${MONGOD_PORT} <<<'rs.status()' 
        exit $?
        ;;
    run)
	${MONGO} ${MONGOD_IP}:${MONGOD_PORT} < $2
        exit $?
        ;;
    locate)
	echo ${MONGOD_IP}:${MONGOD_PORT}
        exit $?
        ;;
    *)
        echo "USAGE : (help|start|repair|stop|rotate|status|locate)"
        exit 1;
        ;;
esac
exit $?
