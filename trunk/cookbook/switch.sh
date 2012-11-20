#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh NODES_MASTER_SLAVE.sh


export MASTER=${MASTERS[0]}

master_position=`$TREPCTL -host $MASTER flush|cut -d':' -f2`


for SLAVE in ${SLAVES[*]} 
do
	$TREPCTL -host $SLAVE wait -applied $master_position
	$TREPCTL -host $SLAVE offline
done

$TREPCTL -host $MASTER offline


. ./cookbook/USER_VALUES.sh NODES_SWITCH.sh

export MASTER=${MASTERS[0]}

$TREPCTL -host $MASTER setrole -role master
$TREPCTL -host $MASTER online

for SLAVE in ${SLAVES[*]} 
do
	$TREPCTL -host $SLAVE setrole -role slave -uri thl://$MASTER:2112
	$TREPCTL -host $SLAVE online
done

./cookbook/show_cluster.sh NODES_SWITCH.sh