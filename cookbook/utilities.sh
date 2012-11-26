#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19
if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi
. ./cookbook/BOOTSTRAP.sh COMMON_NODES.sh


function fill_roles {
    SLAVE_COUNT=0
    MASTER_COUNT=0
    SLAVES=()
    MASTERS=()
    for NODE in ${ALL_NODES[*]} 
    do 
        for role in $($TREPCTL -host $NODE services |grep role | awk '{print $3}')
        do
            if [ "$role" == "master" ]
            then
                MASTERS[$MASTER_COUNT]=$NODE
                MASTER_COUNT=$(($MASTER_COUNT+1))
            fi
            if [ "$role" == "slave" ]
            then
                SLAVES[$SLAVE_COUNT]=$NODE
                SLAVE_COUNT=$(($SLAVE_COUNT+1))
            fi
        done
    done
    export  MASTERS=(${MASTERS[*]})
    export SLAVES=(${SLAVES[*]})
}

function clear_node {
	
		NODE=$1
		MYSQL="mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"
		ssh $NODE "if [ ! -d $TUNGSTEN_BASE ] ; then mkdir -p $TUNGSTEN_BASE ;  fi" 
	    ssh $NODE "if [ -x $REPLICATOR ] ; then $REPLICATOR stop;  fi" 
	    ssh $NODE rm -rf $TUNGSTEN_BASE/*  
	    for D in $($MYSQL -h $NODE -BN -e 'show schemas like "tungsten%"' )
	    do
	        $MYSQL -h $NODE -e "drop schema $D"
	    done
	    $MYSQL -h $NODE -e 'drop schema if exists test'
	    $MYSQL -h $NODE -e 'drop schema if exists evaluator'
	    $MYSQL -h $NODE -e 'create schema test'
	    $MYSQL -h $NODE -e 'set global read_only=0'
	    $MYSQL -h $NODE -e 'set global binlog_format=mixed'
	    $MYSQL -h $NODE -e 'reset master'	
	
}
