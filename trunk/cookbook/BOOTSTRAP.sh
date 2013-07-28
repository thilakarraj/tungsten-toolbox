#!/bin/bash
# (C) Copyright 2012,2013 Continuent, Inc - Released under the New BSD License
# Version 1.0.5 - 2013-04-03

cookbook_dir=$(dirname $0)
cd "$cookbook_dir/.."

NODES=$1
if [ -z "$NODES" ]
then
    echo "We need a NODES file to work with"
    exit 1
fi

CURDIR=`dirname $0`

if [ -x "$CURDIR/simple_services" ]
then
    SIMPLE_SERVICES=$CURDIR/simple_services
else
    for P in `echo $PATH |tr ':' ' '` 
    do
        if [ -x $P/simple_services ]
        then
            SIMPLE_SERVICES=$P/simple_services
            continue
        fi
    done
fi

if [ -z "$SIMPLE_SERVICES" ]
then
    echo "simple_services is not installed. "
    echo "While not strictly necessary for the recipes installation, it is needed to run the auxuliary scripts."
    echo "Please get it from http://code.google.com/p/tungsten-toolbox/ and put it in the \$PATH"
    exit 1
fi

if [ ! -f $cookbook_dir/$NODES ]
then
    echo "$cookbook_dir/$NODES not found"
    exit 1
fi

. $cookbook_dir/$NODES

if [ -z "${ALL_NODES[0]}" ]
then
    echo "Nodes variables not set"
    echo "Please edit cookbook/COMMON_NODES.sh or cookbook/NODES*.sh"
    echo "Make sure that NODE1, NODE2, etc are filled"
    exit 1
fi

HOSTS_LIST=""
MASTERS_LIST=""
SLAVES_LIST=""
MASTER_SERVICES_LIST=""
export LONG_LINE="--------------------------------------------------------------------------------------"

for NODE in ${ALL_NODES[*]}
do
   [ -n "$HOSTS_LIST" ] && HOSTS_LIST="$HOSTS_LIST,"
   HOSTS_LIST="$HOSTS_LIST$NODE"
done

service_count=0
for NODE in ${SLAVES[*]}
do
   [ -n "$SLAVES_LIST" ] && SLAVES_LIST="$SLAVES_LIST,"
   SLAVES_LIST="$SLAVES_LIST$NODE"
done

service_count=0
for NODE in ${MASTERS[*]}
do
    unset SKIP
    if [ -n "$HUB" ]
    then
        if [ "$HUB" == "$NODE" ]
        then
            SKIP=1
            service_count=$(($service_count+1))
        fi
    fi
    if [ -z "$SKIP" ]
    then
        [ -n "$MASTERS_LIST" ] && MASTERS_LIST="$MASTERS_LIST,"
        [ -n "$MASTER_SERVICES_LIST" ] && MASTER_SERVICES_LIST="$MASTER_SERVICES_LIST,"
        MASTERS_LIST="$MASTERS_LIST$NODE"
        MASTER_SERVICES_LIST="$MASTER_SERVICES_LIST${MM_SERVICES[$service_count]}"
        service_count=$(($service_count+1))
    fi
done

export MASTERS_LIST
export SLAVES_LIST
export HOSTS_LIST
export MASTER_SERVICES_LIST

CURRENT_HOST=$(hostname)
INSTALLER_IN_CLUSTER=0
# CURRENT_HOST_IP=$(hostname --ip)
CURRENT_HOST_IPs=$(/sbin/ifconfig |perl -lne 'if ( /inet/) {print $1 if /\s*(\d+\.\d+\.\d+\.\d+)/}')


function check_if_installer_is_in_cluster
{
    for HOST in ${ALL_NODES[*]}
    do
        if [ "$HOST" == "$CURRENT_HOST" ]
        then
            INSTALLER_IN_CLUSTER=1
            return
        else
            for CURRENT_HOST_IP in $CURRENT_HOST_IPs
            do
                if [ "$CURRENT_HOST_IP" != '127.0.0.1' ]
                then
		    # Check if the IP for the hostname is associated with
		    # one of the hosts defined for this cluster
		    for LINE in $(grep $CURRENT_HOST_IP /etc/hosts | grep -v '^#')
		    do
			for ITEM in $LINE
			do
			    if [ "$ITEM" == "$HOST" ]
			    then
				INSTALLER_IN_CLUSTER=1
				return
			    fi
			done 
		    done
                fi
            done
        fi
    done
}

check_if_installer_is_in_cluster

if [ "$INSTALLER_IN_CLUSTER" != "1" ]
then
    echo "This framework is designed to act within the cluster that is installing"
    echo "The current host ($CURRENT_HOST) is not among the designated servers (${ALL_NODES[*]})"
    exit 1
fi

. $cookbook_dir/USER_VALUES.sh

[ -z "$MY_CNF" ] && export MY_CNF=/etc/my.cnf
if [ ! -f $MY_CNF ]
then
    UBUNTU_MY_CNF=/etc/mysql/my.cnf
    if [ -f $UBUNTU_MY_CNF ]
    then
        MY_CNF=$UBUNTU_MY_CNF
    else
        echo "could not find a configuration file (either $MY_CNF or $UBUNTU_MY_CNF)"
        exit 1
    fi
fi

export REPLICATOR=$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/replicator
export TREPCTL="$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/trepctl -port $RMI_PORT"
export THL=$TUNGSTEN_BASE/tungsten/tungsten-replicator/bin/thl
export INSTALL_LOG=$cookbook_dir/current_install.log
export INSTALL_SUMMARY=$cookbook_dir/current_install.summary

CURRENT_TOPOLOGY=$cookbook_dir/../CURRENT_TOPOLOGY
MY_COOKBOOK_CNF=$cookbook_dir/my.cookbook.cnf
MYSQL="mysql --defaults-file=$MY_COOKBOOK_CNF"
MYSQLDUMP="mysqldump --defaults-file=$MY_COOKBOOK_CNF"
MYSQLADMIN="mysqladmin --defaults-file=$MY_COOKBOOK_CNF"

function check_installed
{
    if [ -f $CURRENT_TOPOLOGY ]
    then
        echo "There is a previous installation recorded in $CURRENT_TOPOLOGY"
        cat $CURRENT_TOPOLOGY
        TOPOLOGY=$(cat $CURRENT_TOPOLOGY)
        echo "Run cookbook/clear_cluster to remove this installation"
        exit 1
    fi 
}

function check_current_topology
{
    if [ -f $CURRENT_TOPOLOGY ]
    then
        WANTED=$1
        TOPOLOGY=$(cat $CURRENT_TOPOLOGY)
        if [ "$TOPOLOGY" != "$WANTED" ]
        then
            echo "this script requires a $WANTED topology."
            echo "Found a different topology ($TOPOLOGY) in $CURRENT_TOPOLOGY"
            exit 1
        fi
    else
        echo "$CURRENT_TOPOLOGY not found"
        echo "Cannot determine if $WANTED topology is deployed"
        exit 1
    fi
}

function are_you_sure_you_want_to_clear
{
    echo $LONG_LINE
    echo "!!! WARNING !!!"
    echo $LONG_LINE
    echo "'clear-cluster' is a potentially damaging operation."
    echo "This command will do all the following:"
    if [ "$STOP_REPLICATORS" == 1 ]
    then
        echo "* Stop the replication software in all servers. [\$STOP_REPLICATORS]"
    fi
    if [ "$REMOVE_TUNGSTEN_BASE" == "1" ]
    then
        echo "* REMOVE ALL THE CONTENTS from $TUNGSTEN_BASE/.[\$REMOVE_TUNGSTEN_BASE]"
    fi
    if [ "$REMOVE_SERVICE_SCHEMA" == "1" ]
    then
        echo "* REMOVE the tungsten_<service_name> schemas in all nodes (${ALL_NODES[*]}) [\$REMOVE_SERVICE_SCHEMA] "
    fi
    if [ "$REMOVE_TEST_SCHEMAS" == "1" ]
    then
        echo "* REMOVE the schemas created for testing (test, evaluator) in all nodes (${ALL_NODES[*]})  [\$REMOVE_TEST_SCHEMAS]"
    fi
    if [ "$REMOVE_DATABASE_CONTENTS" == "1" ]
    then
        echo "* REMOVE *** ALL THE DATABASE CONTENTS *** in all nodes (${ALL_NODES[*]}) [\$REMOVE_DATABASE_CONTENTS] "
    fi
    if [ "$CLEAN_NODE_DATABASE_SERVER" == "1" ]
    then
        echo "* Create the test server anew;                [\$CLEAN_NODE_DATABASE_SERVER]"
        echo "* Unset the read_only variable;               [\$CLEAN_NODE_DATABASE_SERVER]"
        echo "* Set the binlog format to MIXED;             [\$CLEAN_NODE_DATABASE_SERVER]"
        echo "* Reset the master (removes all binary logs); [\$CLEAN_NODE_DATABASE_SERVER]"
    fi
    if [ -z "$I_WANT_TO_UNINSTALL" ]
    then
        echo "If this is what you want, either set the variable I_WANT_TO_UNINSTALL "
        echo "or answer 'y' to the question below"
        echo "You may also set the variables in brackets to fine tune the execution."
        echo "Alternatively, have a look at $0 and customize it to your needs."
    else
        echo "***"
        echo "The variable \$I_WANT_TO_UNINSTALL was set. No confirmation is required."
        echo "***"
    fi
    echo "--------------------------------------------------------------------------------------"

    while [ -z "$I_WANT_TO_UNINSTALL" ] ; do
        read -p 'Do you wish to uninstall this cluster? [y/n] ' yn 
        case $yn in 
            [Yy]* ) I_WANT_TO_UNINSTALL=YES;; 
            [Nn]* ) exit;;
            * ) echo 'Please answer (y) or (n).';;
        esac
    done
}

function write_my_cookbook_cnf
{
    echo '[client]'                           > $MY_COOKBOOK_CNF
    echo "user=$DATABASE_USER"               >> $MY_COOKBOOK_CNF
    echo "password=$DATABASE_PASSWORD"       >> $MY_COOKBOOK_CNF
    echo "port=$DATABASE_PORT"               >> $MY_COOKBOOK_CNF
    echo "host=__HOST__"                     >> $MY_COOKBOOK_CNF
    echo ''                                  >> $MY_COOKBOOK_CNF
    echo '[mysql]'                           >> $MY_COOKBOOK_CNF
    echo "prompt='*mysql [\h] {\u} (\d) > '" >> $MY_COOKBOOK_CNF
}

function post_installation
{
    write_my_cookbook_cnf
    TOPOLOGY=$(cat $CURRENT_TOPOLOGY)
    DB_USE=$cookbook_dir/db_use
    TUNGSTEN_RELEASE=$(grep RELEASE $cookbook_dir/../.manifest| awk '{print $2}')  
    echo "Deployment completed "
    echo "Topology         :'$TOPOLOGY'"                                            > $INSTALL_SUMMARY
    echo "Tungsten path    : $TUNGSTEN_BASE "                                      >> $INSTALL_SUMMARY
    echo "Nodes            : (${ALL_NODES[*]})"                                    >> $INSTALL_SUMMARY
    echo "Master services  : (${MASTERS[*]})"                                      >> $INSTALL_SUMMARY
    echo "Slave services   : (${SLAVES[*]})"                                       >> $INSTALL_SUMMARY
    echo "MySQL version    : $($MYSQL -h ${MASTERS[0]} -BN -e 'select @@version')" >> $INSTALL_SUMMARY
    echo "MySQL port       : $DATABASE_PORT"                                       >> $INSTALL_SUMMARY
    echo "MySQL shortcut   : $MYSQL"                                               >> $INSTALL_SUMMARY
    echo "                 : (or $DB_USE)"                                         >> $INSTALL_SUMMARY
    echo "Tungsten release : $TUNGSTEN_RELEASE"                                    >> $INSTALL_SUMMARY
    echo "Installation log : $INSTALL_LOG"                                         >> $INSTALL_SUMMARY


    MY_BARE_CNF=$(basename $MY_COOKBOOK_CNF)
    echo "#!/bin/bash" > $DB_USE
    echo 'cookbook_dir=$(dirname $0)' >> $DB_USE
    echo "mysql --defaults-file=\$cookbook_dir/$MY_BARE_CNF \$*" >> $DB_USE
    chmod +x $DB_USE

    for NODE in ${ALL_NODES[*]}
    do  
        MY_REMOTE_CNF=/tmp/my_template$$.cnf
        cp $MY_COOKBOOK_CNF $MY_REMOTE_CNF
        perl -i -pe "s/__HOST__/$NODE/" $MY_REMOTE_CNF
        DEPLOYED=$(ssh $NODE "if [ -d $TUNGSTEN_BASE ] ; then echo 'yes' ; fi")
        if [ "$DEPLOYED" == "yes" ]
        then
            scp -q $CURRENT_TOPOLOGY $NODE:$TUNGSTEN_BASE/tungsten/  
            scp -q $MY_REMOTE_CNF $NODE:$TUNGSTEN_BASE/tungsten/cookbook/$MY_BARE_CNF
            scp -q $INSTALL_LOG $NODE:$TUNGSTEN_BASE/tungsten/cookbook/
            scp -q $INSTALL_SUMMARY $NODE:$TUNGSTEN_BASE/tungsten/cookbook/
            scp -q $DB_USE $NODE:$TUNGSTEN_BASE/tungsten/cookbook/
        fi
        rm $MY_REMOTE_CNF
    done
    cp $TUNGSTEN_BASE/tungsten/cookbook/$MY_BARE_CNF $MY_COOKBOOK_CNF
    cat $INSTALL_SUMMARY

}

