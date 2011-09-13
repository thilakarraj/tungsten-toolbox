#!/bin/bash
#sysbench_oltp_test

##
## Easy parameters:
##
# how to access the database
if [ -f /tmp/HOST_PARAMS.sh ]
then
    . /tmp/HOST_PARAMS.sh
else
    echo "/tmp/HOST_PARAMS.sh not found. Exiting"
    exit 1
fi

TEST_DB=$1
OPERATION=$2

if [  -z $OPERATION ]
then
    echo "syntax $0 database_name operation "
    echo "operation: {prepare|run}"
    exit 1
fi

#
# How many seconds will the test run
# 300 seconds = 5 minutes
#
DURATION=$SYSBENCH_DURATION
if [ -z $DURATION ]
then
    DURATION=600
fi

# read-only settings
# on = read-ony
# off = read and write
ON_OFF=off

START_TEST=$(date '+%Y-%m-%d %H:%M:%S')

if [ "$OPERATION" == "prepare" ]
then
    mysql -h $HOST -P $PORT -u $DB_USER -p$DB_PASSWD -e "drop schema if exists $TEST_DB"
    mysql -h $HOST -P $PORT -u $DB_USER -p$DB_PASSWD -e "create schema $TEST_DB"
fi

if [ "$OPERATION" == "run" ]
then
    mysql -h $HOST -P $PORT -u $DB_USER -p$DB_PASSWD -e "drop table if exists first_table" $TEST_DB
    mysql -h $HOST -P $PORT -u $DB_USER -p$DB_PASSWD -e "create table first_table(i int)" $TEST_DB
fi

sysbench \
    --test=oltp \
    --db-driver=mysql \
    --oltp-table-size=$ROWS \
    --mysql-db=$TEST_DB \
    --mysql-user=$DB_USER \
    --mysql-password=$DB_PASSWD \
    --mysql-host=$HOST \
    --mysql-port=$PORT \
    --oltp-read-only=$ON_OFF \
    --oltp-index-updates=4 \
    --oltp-non-index-updates=2 \
    --max-time=$SYSBENCH_DURATION \
    --max-requests=$MAX_REQUESTS \
    --num-threads=$NUM_THREADS $OPERATION

END_TEST=$(date '+%Y-%m-%d %H:%M:%S')
echo $START_TEST
echo $END_TEST

mysql -h $HOST -P $PORT -u $DB_USER -p$DB_PASSWD \
    -e "select timediff('$END_TEST', '$START_TEST') as 'time spent running the test'"

if [ "$OPERATION" == "run" ]
then
    mysql -h $HOST -P $PORT -u $DB_USER -p$DB_PASSWD -e "create table $TEST_DB.last_table(i int)"
fi
