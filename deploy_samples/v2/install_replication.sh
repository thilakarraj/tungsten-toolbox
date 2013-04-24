#!/bin/bash

if [ ! -f ./bootstrap.sh ]
then
    echo "Configuration file bootstrap.sh not found"
    exit 1
fi

. ./bootstrap.sh

if [ -f $BANNER ]
then
   echo "*****  Replication already installed"
   echo $DASH_LINE
   cat $BANNER
   echo $DASH_LINE
   exit 1
fi
echo "# Making sure MySQL is running"

MYSQL="$BASEDIR/bin/mysql"
if [ ! -x $MYSQL ]
then
    echo "Could not find $MYSQL"
    exit 1
fi

echo "[client]" > user$$.cnf
echo "user=$DB_USER" >> user$$.cnf
echo "password=$DB_PASSWORD" >> user$$.cnf

echo "[client]" > repl$$.cnf
echo "user=$DB_USER" >> repl$$.cnf
echo "password=$DB_PASSWORD" >> repl$$.cnf

MYSQL_SLAVE="$MYSQL --defaults-file=$PWD/repl$$.cnf --port=$DB_PORT"
MYSQL="$MYSQL --defaults-file=$PWD/user$$.cnf --port=$DB_PORT"
ALL_RUNNING=1

for NODE in ${MASTERS[*]}
do
    RUNNING=$($MYSQL_SLAVE -BN --host=$NODE -e 'select 1')
    if [ -n "$RUNNING" ]
    then
        echo "# MASTER $NODE: ok"
    else
        echo "# WARNING: mysql not reachable by user $REPL_SLAVE in node $NODE"
        ALL_RUNNING=0
    fi  
done

for NODE in ${ALL_NODES[*]}
do
    RUNNING=$($MYSQL -BN --host=$NODE -e 'select 1')
    if [ -n "$RUNNING" ]
    then
        echo "# Node $NODE: ok"
    else
        echo "# WARNING: mysql not reachable in node $NODE"
        ALL_RUNNING=0
    fi  
done

if [ "$ALL_RUNNING" == "0" ]
then
    exit 1
fi

echo "# making sure the servers have binary log enabled and server-id"

for NODE in ${ALL_NODES[*]}
do
    
    SERVER_ID=$($MYSQL -BN --host=$NODE -e 'select @@server_id')
    if [ $SERVER_ID -lt 1 ]
    then
        echo "Node $NODE has a ZERO server ID" 
        exit 1
    else
        echo "# node $NODE - server_id: $SERVER_ID"
    fi

    LOG_BIN=$($MYSQL -BN --host=$NODE -e 'select @@log_bin')
    if [ "$LOG_BIN" == "0" ]
    then
        echo "Node $NODE has binary logs disabled" 
        exit 1
    else
        echo "# node $NODE - log_bin: $LOG_BIN"
    fi
done

for MASTER in ${MASTERS[*]}
do  
    $MYSQL --host=$MASTER -e 'reset master'
    BINLOG_FILE=$($MYSQL --host=$MASTER -e 'show master status\G' | grep File | awk '{print $2}' )
    BINLOG_POS=$($MYSQL --host=$MASTER -e 'show master status\G' | grep Position | awk '{print $2}' )

    for NODE in ${SLAVES[*]}
    do
        $MYSQL --host=$NODE -e 'stop slave'
        $MYSQL --host=$NODE -e "CHANGE MASTER TO master_host='$MASTER', master_port=$DB_PORT, master_user='$REPL_USER', master_password='$REPL_PASSWORD', master_log_file='$BINLOG_FILE', master_log_pos=$BINLOG_POS "
        $MYSQL --host=$NODE -e 'start slave'
    done
done
cleanup

# write configuration
echo "Installed using:" > $BANNER
for MASTER in ${MASTERS[*]}
do
    echo " master: $MASTER " >> $BANNER
done
for SLAVE in ${SLAVES[*]}
do
    echo " slave: $SLAVE " >> $BANNER
done

echo " port: $DB_PORT " >> $BANNER
echo " datadir: $DATADIR " >> $BANNER
echo " BASEDIR: $BASEDIR " >> $BANNER
echo " Replication user: $REPL_USER " >> $BANNER
echo " Staging directort: $PWD " >> $BANNER

# write utility scripts
for script in mysql mysqldump mysqladmin
do
    echo '#!/bin/bash' > $script
    echo "$BASEDIR/bin/$script --user=$DB_USER --port=$DB_PORT \$@" >> $script
    chmod +x $script
done  

