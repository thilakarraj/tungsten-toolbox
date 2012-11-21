#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh NODES_MASTER_SLAVE.sh

./cookbook/clear_cluster.sh NODES_MASTER_SLAVE.sh

export MASTER=${MASTERS[0]}
MYSQL="mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"

echo "installing STANDARD" >$INSTALL_LOG
date >> $INSTALL_LOG

MASTER_STATUS=`mysql -h $MASTER -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT -NE -e"show master status"|awk '(NR==2 || NR==3) {print $0}'`
MASTER_FILE=$(echo $MASTER_STATUS | cut --delimiter=' ' -f 1) 
MASTER_POS=$(echo $MASTER_STATUS | cut --delimiter=' ' -f 2)

SQL="change master to master_host='$MASTER',master_user='$DATABASE_USER',master_password='$DATABASE_PASSWORD',master_port=$DATABASE_PORT,master_log_file='$MASTER_FILE',master_log_pos=$MASTER_POS;slave start;"

for SLAVE in ${SLAVES[*]}
do
	$MYSQL -h $SLAVE -e"$SQL"
	echo "Starting slave on $SLAVE Master File = $MASTER_FILE, Master Position = $MASTER_POS"
done
