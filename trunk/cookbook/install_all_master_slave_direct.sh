#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19

if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi
. ./cookbook/BOOTSTRAP.sh NODES_MASTER_SLAVE.sh

export MASTER=${MASTERS[0]}

check_installed


echo "installing MASTER_SLAVE_DIRECT" >$INSTALL_LOG
date >> $INSTALL_LOG

# install master_slave_direct
INDEX=0
for NODE in ${SLAVES[*]}
do
  INSTALL_COMMAND="/tmp/tungsten-install/tools/tungsten-installer \
    --direct \
    --master-host=$MASTER \
    --master-port=$DATABASE_PORT \
    --master-user=$DATABASE_USER \
    --master-password=$DATABASE_PASSWORD \
    --slave-host=$MASTER \
    --slave-port=$DATABASE_PORT \
    --slave-user=$DATABASE_USER \
    --slave-password=$DATABASE_PASSWORD \
    --service-name=$TUNGSTEN_SERVICE \
    --home-directory=$TUNGSTEN_BASE \
    --slave-host=$NODE \
    $MORE_OPTIONS --$START_OPTION"

    echo $INSTALL_COMMAND  | perl -pe 's/--/\n\t--/g' >> $INSTALL_LOG
    if [ -n "$VERBOSE" ]
    then
        echo $INSTALL_COMMAND | perl -pe 's/--/\n\t--/g'
    fi
    
    ssh $NODE "[ ! -d '/tmp/tungsten-install' ] && mkdir /tmp/tungsten-install"
    rsync -avzP -e ssh  . $NODE:/tmp/tungsten-install/  > /dev/null 
    ssh $NODE $INSTALL_COMMAND

    if [ "$?" != "0"  ]
    then
        exit
    fi
done

 
for NODE in ${SLAVES[*]}
do
	tungsten-replicator/bin/trepctl -host $NODE services | cookbook/simple_services
done

echo "master_slave_direct" > $CURRENT_TOPOLOGY
 
