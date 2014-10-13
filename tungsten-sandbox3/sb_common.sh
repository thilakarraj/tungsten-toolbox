sandboxdir=$(dirname $0)
. $sandboxdir/sb_vars.sh 

STEPNO=0
INI_NODE=0

function make_paths
{
    PATHS=''
    for D in $( find  $TUNGSTEN_SB -maxdepth 1 -type d -name "${SB_PREFIX}*"  )
    do
        if [ -n "$PATHS" ] ; then PATHS="$PATHS,"; fi
        PATHS="${PATHS}${D}"
    done
    export PATHS
}

function check_exit_code
{
    exit_code=$?
    if [ -n "$SBDEBUG" ]
    then
        echo "# exit code: <$exit_code>"
    fi
    if [ "$exit_code" != "0" ] 
    then 
        exit $exit_code 
    fi
}

function multi_trepctl
{
    make_paths
    MULTI_TREPCTL="$TUNGSTEN_SB_NODE2/tungsten/tungsten-replicator/scripts/multi_trepctl --paths=$PATHS"
    FIELDS=--fields=host,rmiPort,service,role,state,seqno,latency
    if [ -z "$1" ]
    then
        $MULTI_TREPCTL $FIELDS
    else
        $MULTI_TREPCTL "$@"
    fi
}

function show_command
{
    command=$1
    if [ -n "$MAKE_INI" ]
    then
        echo $command | perl -pe 's{(./tools/tpm install)}{}; s/\breset\b//; s{./tools/tpm configure (\w+)}{\n\[$1\]}; s/--/\n/g; ' >> $TUNGSTEN_SB/tungsten-node$INI_NODE.ini
    else
        echo $command | perl -pe 'BEGIN{$HN=qx(hostname); chomp $HN}; s/$ENV{HOME}/\$HOME/g; s/=$ENV{USER}\b/=\$USER/g; s/\b$HN\b/\$(hostname)/g; s/--/\\\n\t--/g'
    fi
}

function run_command
{
    command="$1"
    if [ -n "$DRYRUN" -o -n "$SBDEBUG" -o -n "$VERBOSE" ]
    then
        show_command "$command"
    fi
    if [ -z "$DRYRUN" ]
    then
        $command
        check_exit_code
    fi
}

function print_dry
{
    message=$1
    STEPNO=$(($STEPNO+1))
    if [ -n "$DRYRUN" ]
    then
        echo "# --- step $STEPNO --- "
    fi
    if [ -n "$DRYRUN" -o -n "$SBDEBUG" -o -n "$VERBOSE" ]
    then
        echo $message
    fi
    if [ -n "$DRYRUN" ]
    then
        echo "# "
    fi
}

function configure_defaults
{
    NODE=$1   
    if [ -n "$MAKE_INI" ]
    then
        export INI_NODE=$NODE
        echo "# NODE $NODE - Topology: $current_topology" > $TUNGSTEN_SB/tungsten-node$INI_NODE.ini
    fi
    DISABLE_RELAY_LOGS=true
    if [ "$current_topology" == "direct" ]
    then
        DISABLE_RELAY_LOGS=false
    fi
    DELTA=$(($NODE*10))
    EXTRA_OPTIONS=''
    if [ -n "$MORE_NODE_OPTIONS" ]
    then
        WANTED_NODE=$(echo $MORE_NODE_OPTIONS | tr ':' ' '| awk '{print $1}' )
        if [ "$WANTED_NODE" == "$NODE" ]
        then
            EXTRA_OPTIONS=$(echo "$MORE_NODE_OPTIONS" | perl -nle 's/^\d+://; print "$_"')
        fi
    fi
    print_dry "# Configuring node $NODE"
    if [ -n "$SET_EXECUTABLE_PREFIX" ]
    then
        EXTRA_OPTIONS="$EXTRA_OPTIONS --executable-prefix=${SB_PREFIX}$NODE"
    fi
    MYSQL_SB_PATH=$MYSQL_SB_BASE/node$NODE
    
    if [ -n "$USE_SSL" ]
    then
        SSL_OPTIONS="--datasource-enable-ssl=true"
        SSL_OPTIONS="$SSL_OPTIONS --java-keystore-path=$sandboxdir/ssl/tungsten_keystore.jks "
        SSL_OPTIONS="$SSL_OPTIONS --java-truststore-path=$sandboxdir/ssl/tungsten_truststore.ts "
    fi
    TPM_COMMAND="./tools/tpm configure defaults --reset \
        --install-directory=$TUNGSTEN_SB/$SB_PREFIX$NODE \
        --repl-rmi-port=$(($RMI_BASE_PORT+$DELTA)) \
        --user=$USER \
        --replication-port=$(($MYSQL_BASE_PORT+NODE)) \
        --datasource-mysql-conf=$MYSQL_SB_PATH/my.sandbox.cnf \
        --datasource-boot-script=$MYSQL_SB_PATH/msb \
        --datasource-log-directory=$MYSQL_SB_PATH/data \
        --repl-disable-relay-logs=$DISABLE_RELAY_LOGS \
        $USERNAME_AND_PASSWORD \
        $VALIDATION_CHECKS $MORE_DEFAULTS_OPTIONS $EXTRA_OPTIONS $SSL_OPTIONS \
        --start=true"
    #echo $TPM_COMMAND | perl -pe 's/--/\\\n\t--/g'
    #exit
    #$TPM_COMMAND
    run_command "$TPM_COMMAND"
}

function configure_master
{
    SERVICE=$1
    THL_PORT=$2
    print_dry "# Configuring master for service $SERVICE (thl: $THL_PORT)"
    TPM_COMMAND="./tools/tpm configure $SERVICE \
        --master=$LOCALHOST \
        --replication-host=$LOCALHOST $MORE_MASTER_OPTIONS \
        --thl-port=$THL_PORT "
    run_command "$TPM_COMMAND"
    # check_exit_code
}

function configure_slave
{
    SERVICE=$1
    THL_PORT=$2
    print_dry "# Configuring slave for service $SERVICE (thl: $THL_PORT)"
    TPM_COMMAND="./tools/tpm configure $SERVICE \
        --slaves=$LOCALHOST \
        --replication-host=$LOCALHOST \
        --thl-port=$THL_PORT \
        --master-thl-host=$LOCALHOST \
        --enable-slave-thl-listener=false $MORE_SLAVE_OPTIONS $3 "

    run_command "$TPM_COMMAND"
    #check_exit_code
}

function configure_fileapplier_slave
{
    SERVICE=$1
    THL_PORT=$2
    MASTER_THL_PORT=$3
    NODE=$4
    DELTA=$(($NODE*10))
    [ -z "$file_template" ] && file_template=donothing
    print_dry "# Configuring slave for service $SERVICE (thl: $THL_PORT)"
    TPM_COMMAND="./tools/tpm configure $SERVICE \
        --slaves=$LOCALHOST \
        --master=$LOCALHOST \
        --repl-rmi-port=$(($RMI_BASE_PORT+$DELTA)) \
        --role=slave \
        --batch-enabled=true \
        --batch-load-language=js \
        --batch-load-template=$file_template \
        --datasource-type=file \
        --install-directory=$TUNGSTEN_SB/${SB_PREFIX}$NODE \
        --thl-port=$THL_PORT \
        --master-thl-port=$MASTER_THL_PORT \
        --master-thl-host=$LOCALHOST \
        --enable-slave-thl-listener=false $MORE_SLAVE_OPTIONS \
        $VALIDATION_CHECKS $MORE_DEFAULTS_OPTIONS $EXTRA_OPTIONS "

    # using hive CSV format:
    #  --property=replicator.datasource.global.csvType=hive 


    run_command "$TPM_COMMAND"
    #check_exit_code
}


function configure_mongodb_slave
{
    SERVICE=$1
    THL_PORT=$2
    MASTER_THL_PORT=$3
    NODE=$4
    DELTA=$(($NODE*10))
    print_dry "# Configuring slave for service $SERVICE (thl: $THL_PORT)"
    TPM_COMMAND="./tools/tpm configure $SERVICE \
        --slaves=$LOCALHOST \
        --master=$LOCALHOST \
        --repl-rmi-port=$(($RMI_BASE_PORT+$DELTA)) \
        --role=slave \
        --datasource-type=mongodb \
        --install-directory=$TUNGSTEN_SB/${SB_PREFIX}$NODE \
        --replication-port=$MONGODB_PORT \
        --replication-host=$LOCALHOST \
        --thl-port=$THL_PORT \
        --master-thl-port=$MASTER_THL_PORT \
        --master-thl-host=$LOCALHOST \
        --enable-slave-thl-listener=false $MORE_SLAVE_OPTIONS \
        $VALIDATION_CHECKS $MORE_DEFAULTS_OPTIONS $EXTRA_OPTIONS "

    run_command "$TPM_COMMAND"
    #check_exit_code
}

function configure_direct_slave
{
    SERVICE=$1
    THL_PORT=$2
    print_dry "# Configuring direct slave for service $SERVICE (thl: $THL_PORT)"
    TPM_COMMAND="./tools/tpm configure $SERVICE \
        --topology=direct \
        --master=$LOCALHOST \
        --replication-host=$LOCALHOST \
        --direct-datasource-host=$LOCALHOST \
        --thl-port=$THL_PORT \
        --enable-slave-thl-listener=false $3"
    run_command "$TPM_COMMAND"
    # check_exit_code
}


function configure_spoke_slave
{
    SERVICE=$1
    THL_PORT=$2
    MASTER_SERVICE=$3
    configure_slave $SERVICE $THL_PORT "--svc-allow-any-remote-service=true --property=local.service.name=$MASTER_SERVICE --svc-applier-filters=bidiSlave"
}

function configure_hub_slave
{
    SERVICE=$1
    THL_PORT=$2
    configure_slave $SERVICE $THL_PORT "--log-slave-updates=true"
}

function tpm_install
{
    
    TPM_COMMAND="./tools/tpm install $MORE_TPM_INSTALL_OPTIONS "
    run_command "$TPM_COMMAND"
    # check_exit_code
}

function install_with_ini_files
{
    # set -x
    for F in $TUNGSTEN_SB/tungsten-node?.ini
    do
        MORE_TPM_INSTALL_OPTIONS=--ini=$F
        tpm_install
    done
    # set +x
}


function pre_installation
{
    export current_topology=$1
    if [ ! -x ./tools/tpm ]
    then
        echo "This command requires ./tools/tpm"
        echo "Change directory to a tungsten staging directory and try again"
        exit 1
    fi
    if [ "$current_topology" == "fileapplier" ]
    then
        NEEDED_VERSION=$(grep tungsten-replicator-3 .manifest)
        if [ -z "$NEEDED_VERSION" ]
        then
            echo "This topology requires Tungsten Replicator 3.0 or later"
            exit 1
        fi
        if [ ! -f ./tungsten-replicator/samples/scripts/batch/donothing.js ]
        then
            echo "Needed file not found: ./tungsten-replicator/samples/scripts/batch/donothing.js "
            echo "The file applier requires the script donothing.js"
            exit 1
        fi
    fi
    will_abort=
    for PREV_INSTANCE in $TUNGSTEN_SB_NODE1 $TUNGSTEN_SB_NODE2 $TUNGSTEN_SB_NODE3 $TUNGSTEN_SB_NODE4
    do
        if [ -d $PREV_INSTANCE ]
        then
            echo "Found a previous installation in $PREV_INSTANCE" 
            will_abort=1
        fi 
    done
    if [ -n "$will_abort" ]
    then
        exit 1
    fi
    if [ ! -d $TUNGSTEN_SB ]
    then
        mkdir -p $TUNGSTEN_SB
    fi
}

function set_mongodb_options
{
    MORE_DEFAULTS_OPTIONS="$MORE_DEFAULTS_OPTIONS --java-file-encoding=UTF8 --java-user-timezone=GMT "
    # MORE_DEFAULTS_OPTIONS="$MORE_DEFAULTS_OPTIONS --java-file-encoding=UTF8 "
    MORE_MASTER_OPTIONS="$MORE_MASTER_OPTIONS --enable-heterogenous-master=true "
    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS --enable-heterogenous-slave=true"

    export MORE_DEFAULTS_OPTIONS=$(echo $MORE_DEFAULTS_OPTIONS | tr ' ' '\n' | sort | uniq | xargs echo)
    export MORE_MASTER_OPTIONS=$(echo $MORE_MASTER_OPTIONS     | tr ' ' '\n' | sort | uniq | xargs echo)
    export MORE_SLAVE_OPTIONS=$(echo $MORE_SLAVE_OPTIONS       | tr ' ' '\n' | sort | uniq | xargs echo)
}

function set_fileapplier_options
{
    MORE_DEFAULTS_OPTIONS="$MORE_DEFAULTS_OPTIONS --java-file-encoding=UTF8 --java-user-timezone=GMT "
    # MORE_DEFAULTS_OPTIONS="$MORE_DEFAULTS_OPTIONS --java-file-encoding=UTF8 "

    MORE_MASTER_OPTIONS="$MORE_MASTER_OPTIONS --enable-batch-master=true --repl-svc-extractor-filters=schemachange"

    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS --enable-batch-slave=true "
    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS --repl-svc-applier-filters=monitorschemachange "
    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS --property=replicator.filter.monitorschemachange.notify=true "
    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS --property=replicator.datasource.global.csv.useHeaders=true "
    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS --property=replicator.datasource.global.csvType=custom "
    MORE_SLAVE_OPTIONS="$MORE_SLAVE_OPTIONS '--property=replicator.datasource.global.csv.fieldSeparator=|'"

    export MORE_DEFAULTS_OPTIONS=$(echo $MORE_DEFAULTS_OPTIONS | tr ' ' '\n' | sort | uniq | xargs echo)
    export MORE_MASTER_OPTIONS=$(echo $MORE_MASTER_OPTIONS     | tr ' ' '\n' | sort | uniq | xargs echo)
    export MORE_SLAVE_OPTIONS=$(echo $MORE_SLAVE_OPTIONS       | tr ' ' '\n' | sort | uniq | xargs echo)
}


function post_installation
{
    topology=$1 
    if [ -n "$DRYRUN" ]
    then
        return
    fi 
    
    make_paths
    #MULTI_TREPCTL="$TUNGSTEN_SB_NODE2/tungsten/tungsten-replicator/scripts/multi_trepctl --paths=$PATHS"
    #echo '#!/bin/bash' > $TUNGSTEN_SB/multi_trepctl 
    #echo "$MULTI_TREPCTL \"\$@\"" >> $TUNGSTEN_SB/multi_trepctl
    cp $sandboxdir/{sb_common,sb_vars}.sh $TUNGSTEN_SB
    if [ -f $sandboxdir/sb_dynamic_vars.sh ] 
    then

        echo $DOTS_LINE >  $TUNGSTEN_SB/sb_vars.sh
        echo "# DYNAMIC variables" >>  $TUNGSTEN_SB/sb_vars.sh
        echo $DOTS_LINE >>  $TUNGSTEN_SB/sb_vars.sh
        cat $sandboxdir/sb_dynamic_vars.sh >> $TUNGSTEN_SB/sb_vars.sh
        echo $DOTS_LINE >>  $TUNGSTEN_SB/sb_vars.sh
        cat $sandboxdir/sb_vars.sh >> $TUNGSTEN_SB/sb_vars.sh
    fi
    cp $sandboxdir/{README.md,sb_multi_trepctl,sb_show_cluster,sb_test_sandbox} $TUNGSTEN_SB
    cp $sandboxdir/sb_reset $TUNGSTEN_SB/sb_erase_sandbox
    #chmod +x $TUNGSTEN_SB/multi_trepctl

    for TPATH in $(echo $PATHS | tr ',' ' ')
    do
        TREPCTL="$TPATH/tungsten/tungsten-replicator/bin/trepctl"
        THL="$TPATH/tungsten/tungsten-replicator/bin/thl"
        REPLICATOR="$TPATH/tungsten/tungsten-replicator/bin/replicator"
        LOG="$TPATH/tungsten/tungsten-replicator/log/trepsvc.log"
        CONF="$TPATH/tungsten/tungsten-replicator/conf/"
        echo '#!/bin/bash' > $TPATH/trepctl 
        echo "$TREPCTL \"\$@\"" >> $TPATH/trepctl
        echo '#!/bin/bash' > $TPATH/thlcmd
        echo "$THL \"\$@\"" >> $TPATH/thlcmd
        echo '#!/bin/bash' > $TPATH/replicator
        echo "$REPLICATOR \"\$@\"" >> $TPATH/replicator
        echo '#!/bin/bash' > $TPATH/show_log
        echo "$EDITOR $LOG" >> $TPATH/show_log
        echo '#!/bin/bash' > $TPATH/show_conf
        echo "$EDITOR $CONF" >> $TPATH/show_conf
        echo '#!/bin/bash' > $TPATH/tpm
        echo ". $TUNGSTEN_SB/sb_vars.sh" >> $TPATH/tpm
        echo "if [ ! -d $TPATH/tungsten ] ; then echo './tungsten not found in $TPATH' ; exit 1 ; fi" >> $TPATH/tpm
        echo "cd $TPATH/tungsten" >> $TPATH/tpm
        echo './tools/tpm "$@"' >> $TPATH/tpm
        for F in replicator thlcmd trepctl show_log show_conf tpm
        do
            chmod +x $TPATH/$F
        done
    done
    for F in  $(ls $MYSQL_SB_BASE/n[0-9]) $MYSQL_SB_BASE/{start_all,stop_all,status_all,restart_all,use_all}
    do
        NF=$(basename $F)
        ln -s $F $TUNGSTEN_SB/db_$NF
    done
    for NODE in $(seq 1 $HOW_MANY_NODES)
    do
        if [ -d $TUNGSTEN_SB/$SB_PREFIX$NODE ]
        then
            ln -s $MYSQL_SB_BASE/node$NODE/use $TUNGSTEN_SB/$SB_PREFIX$NODE/db_use
            ln -s $MYSQL_SB_BASE/node$NODE/my.sandbox.cnf $TUNGSTEN_SB/$SB_PREFIX$NODE/my.cnf
        fi
    done
    echo $topology > $TUNGSTEN_SB/topology
    INFO_FILE=$TUNGSTEN_SB/tungsten_sandbox.info
    TUNGSTEN_BUILD=$(grep '^RELEASE' .manifest | awk '{print $2}')
    echo "Tungsten Sandbox  $TUNGSTEN_SANDBOX_VERSION" > $INFO_FILE
    echo "Topology          : $topology" >> $INFO_FILE
    echo "Tungsten build    : $TUNGSTEN_BUILD" >> $INFO_FILE
    echo "Staging directory : $PWD" >> $INFO_FILE
    echo "MySQL Version     : $MYSQL_VERSION" >> $INFO_FILE
    echo "Nodes             : $HOW_MANY_NODES" >> $INFO_FILE
    cat $INFO_FILE
    $sandboxdir/sb_show_cluster
}

function ok_equal
{
    value=$1
    expected=$2
    msg=$3
    
    test_status=''
    if [ "${value}" == "${expected}.0" ]
    then
        expected="${expected}.0"
    fi
    if [ "${value}" == "$expected.000" ]
    then
        expected="${expected}.000"
    fi

    status_msg="(found <$value> - expected: <$expected>)"
    if [ "$value" == "$expected" ]
    then
        test_status=ok
        pass=$(($pass+1))
    else
        test_status='not ok'
        fail=$(($fail+1))
    fi
    echo "$test_status - $msg - $status_msg"
    total_tests=$(($total_tests+1))
}

function mongo_start
{
    destination=$1
    MONGODB_DATA=$destination/mongo_data
    MONGODB_HOME=$MONGODB_EXPANDED_TARBALLS/$MONGODB_VERSION

    if [ ! -d $MONGODB_HOME ]
    then
        echo "$MONGODB_HOME not found"
        exit 1
    fi
    if [ ! -d $MONGODB_DATA ]
    then
        mkdir -p $MONGODB_DATA
    fi

    $MONGODB_HOME/bin/mongod \
        --logpath=$destination/mongodb.log \
        --dbpath=$MONGODB_DATA \
        --fork \
        --port $MONGODB_PORT \
        --rest
}

function mongodb
{
    $MONGODB_EXPANDED_TARBALLS/$MONGODB_VERSION/bin/mongo --port $MONGODB_PORT "$@"
}

function mongodb_stop
{
    destination=$1
    MONGODB_DATA=$destination/mongo_data
    if [ -d $MONGODB_DATA ]
    then
        (echo "use admin" ; echo "db.shutdownServer()" ) | mongodb
        rm -rf $MONGODB_DATA
    fi
}


