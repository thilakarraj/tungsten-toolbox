#!/bin/bash

NODES=$1
if [ -z "$NODES" ]
then
    echo "We need a NODES file to work with"
    exit 1
fi

if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi

. ./cookbook/USER_VALUES.sh $NODES

MYSQL="mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"
for NODE in ${ALL_NODES[*]} 
do 
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
done

[ -f $INSTALL_LOG ] && rm -f $INSTALL_LOG
