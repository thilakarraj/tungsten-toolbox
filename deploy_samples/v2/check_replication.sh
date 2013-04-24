#!/bin/bash
if [ ! -f ./bootstrap.sh ]
then
    echo "Configuration file bootstrap.sh not found"
    exit 1
fi

. ./bootstrap.sh

if [ ! -f $BANNER ]
then
   echo "Replication not installed"
   exit 1
fi

echo $DASH_LINE
cat $BANNER
echo $DASH_LINE


EXPECTED_MASTER_HOST=${MASTERS[0]}
EXPECTED_MASTER_PORT=$DB_PORT

SLAVE_PORT=$DB_PORT


MASTER="$MYSQL -h $EXPECTED_MASTER_HOST -P $EXPECTED_MASTER_PORT"

$MASTER -e 'SHOW MASTER STATUS\G' > mstatus$$

function extract_value {
    FILENAME=$1
    VAR=$2
    grep -w $VAR $FILENAME | awk '{print $2}'
}

Master_Binlog=$(extract_value mstatus$$ File )
Master_Position=$(extract_value mstatus$$ Position )
rm mstatus$$

for SLAVE_HOST in ${SLAVES[*]}
do

    SLAVE="$MYSQL -h $SLAVE_HOST -P $SLAVE_PORT"
    $SLAVE -e 'SHOW SLAVE STATUS\G' > sstatus$$
    Slave_IO_Running=$(extract_value sstatus$$ Slave_IO_Running)
    Slave_SQL_Running=$(extract_value sstatus$$ Slave_SQL_Running)
    Master_Host=$(extract_value sstatus$$ Master_Host)
    Master_Port=$(extract_value sstatus$$ Master_Port)
    Master_Log_File=$(extract_value sstatus$$ Master_Log_File)
    Read_Master_Log_Pos=$(extract_value sstatus$$ Read_Master_Log_Pos)
    rm sstatus$$

    ERROR_COUNT=0
    if [ "$Master_Host" != "$EXPECTED_MASTER_HOST" ]
    then
        ERRORS[$ERROR_COUNT]="the slave $SLAVE_HOST is not replicating from the host that it is supposed to ($EXPECTED_MASTER_HOST)"
        ERROR_COUNT=$(($ERROR_COUNT+1))
    fi

    if [ "$Master_Port" != "$EXPECTED_MASTER_PORT" ]
    then
        ERRORS[$ERROR_COUNT]="the slave is not replicating from the host that it is supposed to"
        ERROR_COUNT=$(($ERROR_COUNT+1))
    fi

    if [ "$Master_Binlog" != "$Master_Log_File" ]
    then
        ERRORS[$ERROR_COUNT]="master binlog ($Master_Binlog) and Master_Log_File ($Master_Log_File) differ"
        ERROR_COUNT=$(($ERROR_COUNT+1))
    fi

    POS_DIFFERENCE=$(echo ${Master_Position}-$Read_Master_Log_Pos|bc)

    if [ $POS_DIFFERENCE -gt 1000 ]
    then
        ERRORS[$ERROR_COUNT]="The slave is lagging behind of $POS_DIFFERENCE"
        ERROR_COUNT=$(($ERROR_COUNT+1))
    fi

    if [ "$Slave_IO_Running" == "No" ]
    then
        ERRORS[$ERROR_COUNT]="Replication is stopped"
        ERROR_COUNT=$(($ERROR_COUNT+1))
    fi

    if [ "$Slave_SQL_Running" == "No" ]
    then
        ERRORS[$ERROR_COUNT]="Replication (SQL) is stopped"
        ERROR_COUNT=$(($ERROR_COUNT+1))
    fi

    if [ $ERROR_COUNT -gt 0 ]
    then
        EMAIL=myname@gmail.com
        SUBJECT="ERRORS in replication ($SLAVE_HOST)"
        BODY=/tmp/body_msg$$
        CNT=0
        while [ "$CNT" != "$ERROR_COUNT" ]
        do
            echo "${ERRORS[$CNT]}" >> $BODY
            CNT=$(($CNT+1))
        done
        echo "# "
        echo "# sending alert message"
        echo "# "
        echo $SUBJECT
        cat $BODY
        # echo $BODY | mail -s "$SUBJECT" $EMAIL
    else
        echo "SLAVE $SLAVE_HOST : Replication OK"
        printf "file: %s at %'d\n" $Master_Log_File  $Read_Master_Log_Pos
    fi
done
cleanup
