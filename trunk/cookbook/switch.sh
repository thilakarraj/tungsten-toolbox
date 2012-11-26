#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi
. ./cookbook/BOOTSTRAP.sh NODES_MASTER_SLAVE.sh
check_current_topology "master_slave"

function find_roles {
    SLAVE_COUNT=0
    SLAVES=()
    for NODE in ${ALL_NODES[*]} 
    do 
        echo -n "$NODE "
        role=$($TREPCTL -host $NODE services |grep role | awk '{print $3}')
        if [ "$role" == "master" ]
        then
            export MASTER=$NODE
            echo "master"
        else
            SLAVES[$SLAVE_COUNT]=$NODE
            SLAVE_COUNT=$(($SLAVE_COUNT+1))
            echo "slave"
        fi
    done

    if [ -z "$MASTER" ]
    then
        echo "unable to find a master"
        exit 1
    fi
    export  MASTERS=($MASTER)
    export SLAVES=(${SLAVES[*]})
}

find_roles

NEW_MASTER=$1
if [ -z "$NEW_MASTER" ]
then
    NEW_MASTER=${SLAVES[0]}
fi
if [ "$MASTER" == "$NEW_MASTER" ]
then
    echo "designated new master is already a master"
    exit 0
fi

# export MASTER=${MASTERS[0]}

NEW_SLAVES=()
SLAVE_COUNT=0
for NODE in ${ALL_NODES[*]} 
do 
    if [ "$NODE" != "$NEW_MASTER" ]
    then
        NEW_SLAVES[$SLAVE_COUNT]=$NODE
        SLAVE_COUNT=$(($SLAVE_COUNT+1))
    fi
done

master_position=`$TREPCTL -host $MASTER flush|cut -d':' -f2`

for SLAVE in ${SLAVES[*]} 
do
	echo trepctl -host $SLAVE wait -applied $master_position
	$TREPCTL -host $SLAVE wait -applied $master_position
	echo trepctl -host $SLAVE offline
	$TREPCTL -host $SLAVE offline
done

echo trepctl -host $MASTER offline
$TREPCTL -host $MASTER offline


echo trepctl -host $NEW_MASTER setrole -role master
$TREPCTL -host $NEW_MASTER setrole -role master
echo trepctl -host $NEW_MASTER online
$TREPCTL -host $NEW_MASTER online

for SLAVE in ${NEW_SLAVES[*]} 
do
	echo trepctl -host $SLAVE setrole -role slave -uri thl://$NEW_MASTER:2112
	$TREPCTL -host $SLAVE setrole -role slave -uri thl://$NEW_MASTER:2112
	echo trepctl -host $SLAVE online
	$TREPCTL -host $SLAVE online
done

./cookbook/show_master_slave.sh
