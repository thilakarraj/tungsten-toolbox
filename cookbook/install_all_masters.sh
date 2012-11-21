#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19

if [ ! -f ./cookbook/USER_VALUES.sh ]
then
    echo "./cookbook/USER_VALUES.sh not found"
    exit 1
fi
. ./cookbook/USER_VALUES.sh NODES_ALL_MASTERS.sh

check_installed

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
    --datasource-mysql-conf=$MY_CNF \
    --$START_OPTION"

    echo $INSTALL_COMMAND  | perl -pe 's/--/\n\t--/g' >> $INSTALL_LOG
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
            --svc-$START_OPTION ${MM_SERVICES[$M_INDEX]} "

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
        M_INDEX=$(($M_INDEX+1))
    done
    S_INDEX=$(($S_INDEX+1))
done
# set +x
echo "all_masters" > $CURRENT_TOPOLOGY
./cookbook/show_cluster.sh NODES_ALL_MASTERS.sh
