#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

if [ ! -f ./cookbook/BOOTSTRAP.sh ]
then
    echo "./cookbook/BOOTSTRAP.sh not found"
    exit 1
fi
. ./cookbook/BOOTSTRAP.sh NODES_STAR.sh

check_installed

if [ -z "$HUB" ]
then
    echo "HUB undefined. Please update ./cookbook/NODES_STAR.sh"
    exit 1
fi

#./cookbook/clear_cluster.sh NODES_STAR.sh

echo "installing STAR" >$INSTALL_LOG
date >> $INSTALL_LOG

# install STAR
INDEX=0
for NODE in ${MASTERS[*]}
do
  INSTALL_COMMAND="./tools/tungsten-installer \
    --master-slave \
    --master-host=$NODE \
    --datasource-port=$DATABASE_PORT \
    --datasource-user=$DATABASE_USER \
    --datasource-password=$DATABASE_PASSWORD \
    --datasource-log-directory=$BINLOG_DIRECTORY \
    --service-name=${MM_SERVICES[$INDEX]} \
    --home-directory=$TUNGSTEN_BASE \
    --cluster-hosts=$NODE \
    --datasource-mysql-conf=$MY_CNF \
    --datasource-log-directory=$BINLOG_DIRECTORY \
    --rmi-port=$RMI_PORT \
    --thl-port=$THL_PORT \
    $MORE_OPTIONS $START_OPTION "

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
    INDEX=$(($INDEX+1))
done


TUNGSTEN_TOOLS=$TUNGSTEN_BASE/tungsten/tools
HUB_DS=`echo $HUB|perl -lpe's/\W/_/g'`

# set -x
INDEX=0
for NODE in ${MASTERS[*]}
do
    if [ "$NODE" != "$HUB" ]
    then
        # setting a slave service in the spoke
        SPOKE_DS=`echo $NODE|perl -lpe's/\W/_/g'`

        INSTALL_COMMAND="$TUNGSTEN_TOOLS/configure-service \
            -C --quiet \
            --host=$NODE \
            --datasource=$SPOKE_DS \
            --local-service-name=${MM_SERVICES[$INDEX]} \
            --role=slave \
            --service-type=remote \
            -a --svc-allow-any-remote-service=true \
            --release-directory=$TUNGSTEN_BASE/tungsten \
            --skip-validation-check=THLStorageCheck \
            --master-thl-host=$HUB \
            --master-thl-port=$THL_PORT \
            --svc-$START_OPTION  $HUB_SERVICE "

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

        # Setting a slave service on the hub
        INSTALL_COMMAND="$TUNGSTEN_TOOLS/configure-service \
            --quiet -C \
            --host=$HUB \
            --local-service-name=$HUB_SERVICE \
            --role=slave \
            --datasource=$HUB_DS \
            --log-slave-updates=true \
            --service-type=remote \
            --release-directory=$TUNGSTEN_BASE/tungsten \
            --skip-validation-check=THLStorageCheck \
            --master-thl-host=$NODE \
            --master-thl-port=$THL_PORT \
            --svc-$START_OPTION \
            ${MM_SERVICES[$INDEX]}"

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
    fi
    INDEX=$(($INDEX+1))
done
# set +x
echo "star" > $CURRENT_TOPOLOGY
./cookbook/show_cluster.sh NODES_STAR.sh
