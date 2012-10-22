#!/bin/bash

if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh NODES_ALL_MASTERS.sh

./cookbook/clear_cluster.sh NODES_ALL_MASTERS.sh

echo "installing STAR" >$INSTALL_LOG
date >> $INSTALL_LOG

# install all masters
INDEX=0
for NODE in ${MASTERS[*]}
do
  INSTALL_COMMAND="./tools/tungsten-installer \
    --master-slave \
    --master-host=$NODE \
    --datasource-port=$DATABASE_PORT \
    --datasource-user=$DATABASE_USER \
    --datasource-password=$DATABASE_PASSWORD \
    --datasource-log-directory=/var/lib/mysql \
    --service-name=${MM_SERVICES[$INDEX]} \
    --home-directory=$TUNGSTEN_BASE \
    --cluster-hosts=$NODE \
    --start-and-report"

    echo $INSTALL_COMMAND >> $INSTALL_LOG
    $INSTALL_COMMAND

    if [ "$?" != "0"  ]
    then
        exit
    fi
    INDEX=$(($INDEX+1))
done

TUNGSTEN_TOOLS=$TUNGSTEN_BASE/tungsten/tools

# set -x
S_INDEX=0
for SLAVE in ${SLAVES[*]}
do
    M_INDEX=0
    for MASTER in ${MASTERS[*]}
    do
        if [ "$SLAVE" != "$MASTER" ]
        then
            SLAVE_DS=`echo $SLAVE|perl -lpe's/\W/_/g'`

            INSTALL_COMMAND="$TUNGSTEN_TOOLS/configure-service \
            -C --quiet \
            --host=$SLAVE \
            --datasource=$SLAVE_DS \
            --local-service-name=${MM_SERVICES[$S_INDEX]} \
            --role=slave \
            --service-type=remote \
            --release-directory=$TUNGSTEN_BASE/tungsten \
            --skip-validation-check=THLStorageCheck \
            --master-thl-host=$MASTER \
            --svc-start-and-report  ${MM_SERVICES[$M_INDEX]} "

            echo $INSTALL_COMMAND >> $INSTALL_LOG
            $INSTALL_COMMAND
            if [ "$?" != "0"  ]
            then
                exit
            fi
        fi
        M_INDEX=$(($M_INDEX+1))
    done
    S_INDEX=$(($S_INDEX+1))
done
# set +x
./cookbook/show_cluster.sh NODES_ALL_MASTERS.sh
