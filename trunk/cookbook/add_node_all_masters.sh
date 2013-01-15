#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi

if [ ! -f ./cookbook/utilities.sh ]
then
    echo "./cookbook/utilities.sh not found"
    exit 1
fi

. ./cookbook/BOOTSTRAP.sh NODES_ALL_MASTERS.sh
. ./cookbook/utilities.sh

check_current_topology "all_masters"

function find_free_node {
    FREE_COUNT=0
    USED_SERVICE_COUNT=0
    N_INDEX=0
    FREE=()
    USED_SERVICE=()
    for NODE in ${ALL_NODES[*]} 
    do 
        echo -n "$NODE "
        free=$($TREPCTL -host $NODE services |grep role | awk '{print $3}'| wc -l)
        if [ "$free" == "0" ]
        then
				FREE[$FREE_COUNT]=$NODE
	            FREE_SERVICE[$FREE_COUNT]=${MM_SERVICES[$N_INDEX]}
	            FREE_COUNT=$(($FREE_COUNT+1))
			    echo "free"
	    else
	            echo "running"
		fi
		N_INDEX=$(($N_INDEX+1))
    done
    export FREE=(${FREE[*]})
    export FREE_SERVICE=(${FREE_SERVICE[*]})
}

find_free_node

NODE_TO_ADD=${FREE[0]}
SERVICE_TO_ADD="newNode"
DONOR=${SLAVES[0]}

if [ "$NODE_TO_ADD" == '' ]
then
    echo 'No free nodes to add into the cluster'
    exit 1
fi


echo "Populating $NODE_TO_ADD with data from $DONOR"


MYSQL="mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"
MYSQLDUMP="mysqldump -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"

$MYSQLDUMP --all-databases --single-transaction -h $DONOR > /tmp/donor.dmp
$MYSQL -h $NODE_TO_ADD < /tmp/donor.dmp

rm /tmp/donor.dmp

echo "Adding $NODE_TO_ADD into the cluster"

echo "Creating Master replicator on new node"
date >> $INSTALL_LOG

INSTALL_COMMAND="./tools/tungsten-installer \
    --master-slave \
    --master-host=$NODE_TO_ADD \
    --datasource-user=$DATABASE_USER \
    --datasource-password=$DATABASE_PASSWORD \
    --datasource-port=$DATABASE_PORT \
    --service-name=$SERVICE_TO_ADD \
    --home-directory=$TUNGSTEN_BASE \
    --cluster-hosts=$NODE_TO_ADD \
    --datasource-mysql-conf=$MY_CNF \
    --datasource-log-directory=$BINLOG_DIRECTORY \
    --rmi-port=$RMI_PORT \
    --thl-port=$THL_PORT \
    $MORE_OPTIONS --$START_OPTION"     

if [ -n "$VERBOSE" ]
then
    echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g'
fi

echo $INSTALL_COMMAND >> $INSTALL_LOG

$INSTALL_COMMAND

if [ "$?" != "0"  ]
then
    exit
fi

#Add the slave replicators to the new host for all the other master servers
M_INDEX=0
for MASTER in ${MASTERS[*]}
do

        SLAVE_DS=`echo $SLAVE|perl -lpe's/\W/_/g'`

        INSTALL_COMMAND="./tools/configure-service \
        -C --quiet \
        --host=$NODE_TO_ADD \
        --datasource=$NODE_TO_ADD \
        --local-service-name=$SERVICE_TO_ADD \
        --role=slave \
        --service-type=remote \
        --release-directory=$TUNGSTEN_BASE/tungsten \
        --skip-validation-check=THLStorageCheck \
        --master-thl-host=$MASTER \
        --master-thl-port=$THL_PORT \
        --svc-$START_OPTION ${MM_SERVICES[$M_INDEX]} "

        echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g' >> $INSTALL_LOG
        if [ -n "$VERBOSE" ]
        then
            echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g'
        fi

        $INSTALL_COMMAND
        if [ "$?" != "0"  ]
        then
            exit
        fi

    M_INDEX=$(($M_INDEX+1))
done

#Add Slave replicators to the current masters to replicate from new master
M_INDEX=0
for MASTER in ${MASTERS[*]}
do

        SLAVE_DS=`echo $SLAVE|perl -lpe's/\W/_/g'`

        INSTALL_COMMAND="./tools/configure-service \
        -C --quiet \
        --host=$MASTER \
        --datasource=$MASTER \
        --local-service-name=${MM_SERVICES[$M_INDEX]} \
        --role=slave \
        --service-type=remote \
        --release-directory=$TUNGSTEN_BASE/tungsten \
        --skip-validation-check=THLStorageCheck \
        --master-thl-host=$NODE_TO_ADD \
        --master-thl-port=$THL_PORT \
        --svc-$START_OPTION $SERVICE_TO_ADD "

        echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g' >> $INSTALL_LOG
        if [ -n "$VERBOSE" ]
        then
            echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g'
        fi

        $INSTALL_COMMAND
        if [ "$?" != "0"  ]
        then
            exit
        fi

    M_INDEX=$(($M_INDEX+1))
done

./cookbook/show_all_masters.sh
