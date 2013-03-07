#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

NODES=$1
if [ -z "$NODES" ]
then
    echo "We need a NODES file to work with"
    exit 1
fi

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

. ./cookbook/BOOTSTRAP.sh $NODES
. ./cookbook/utilities.sh

fill_roles

MYSQL="mysql -u $DATABASE_USER -p$DATABASE_PASSWORD -P $DATABASE_PORT"

COUNT=0

for NODE in ${MASTERS[*]} 
do 
    COUNT=$(($COUNT+1))
    $MYSQL -h $NODE -e "drop table if exists test.t$COUNT"
    $MYSQL -h $NODE -e "drop table if exists test.v$COUNT"
    $MYSQL -h $NODE -e "create table test.t$COUNT(id int not null primary key, c char(20)) engine=innodb"
    $MYSQL -h $NODE -e "create or replace view test.v$COUNT as select * from test.t$COUNT"
    $MYSQL -h $NODE -e "insert into test.v$COUNT values (1, 'inserted by node #$COUNT')"
done

sleep 2
TESTS=0
for SLAVE in ${SLAVES[*]} 
do
    echo "# slave: $SLAVE"
    COUNT=0
    for NODE in ${MASTERS[*]} 
    do 
        COUNT=$(($COUNT+1))
        TABLE_COUNT=$($MYSQL -BN -h $NODE -e "select count(*) from information_schema.tables where table_schema='test' and  table_name = 't$COUNT'")
        VIEW_COUNT=$($MYSQL -BN -h $NODE -e "select count(*) from information_schema.tables where table_schema='test' and  table_name = 'v$COUNT'")
        RECORD_COUNT=$($MYSQL -BN -h $NODE -e "select count(*) from test.t$COUNT where c = 'inserted by node #$COUNT' ")
        if [ "$TABLE_COUNT" == "1" ] ; then echo -n "ok" ; else echo -n "not ok" ; fi ; echo " - Tables from master #$COUNT"
        TESTS=$((TESTS+1))
        if [ "$VIEW_COUNT" == "1" ] ; then echo -n "ok" ; else echo -n "not ok" ; fi ; echo " - Views from master #$COUNT"
        TESTS=$((TESTS+1))
        if [ "$RECORD_COUNT" == "1" ] ; then echo -n "ok" ; else echo -n "not ok" ; fi ; echo " - Records from master #$COUNT"
        TESTS=$((TESTS+1))
        # $MYSQL -h $NODE -e "select * from test.t$COUNT"
    done
done
echo "1..$TESTS"
