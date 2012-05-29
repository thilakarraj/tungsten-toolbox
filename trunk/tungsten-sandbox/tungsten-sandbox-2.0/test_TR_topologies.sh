#!/bin/bash
# Tests all Tungsten Replicator topologies.
#
# Copyright (C) Giuseppe Maxia, 2012
# for Continuent, Inc
# Released under the New BSD license.

VERSION=1.0.0

TSANDBOX=$HOME/tsb2
if [ -z "$MYSQL_VERSION" ]
then
    MYSQL_VERSION=5.5.24
fi

MAIN_NODE=1
NODES=3

if [ ! -d $TSANDBOX ]
then
    mkdir $TSANDBOX
fi

if [ -z "$TMPDIR" ]
then
    if [ -z "$TEMPDIR" ]
    then
        TMPDIR=/tmp
    else
        TMPDIR=$TEMP
    fi
fi

function show_help {
    echo "usage $0 [options] "
    echo '-v         =>  verbose'
    echo '-h         => help'
    echo '-i dir     => tungsten binaries dir'
    echo '-n nodes   => how many nodes'
    echo '-m version => MySQL version'
    exit 1
}

args=$(getopt hvi:m:n: $*)

if [ $? != 0 ]
then
    show_help
fi

set -- $args

for i
do
    case "$i"
        in
        -v ) 
            VERBOSE=1
            shift 
            ;;
        -h)
            show_help
            ;;
        -i)
            BINDIR=$2
            shift
            shift
            ;;
        -m)
            export MYSQL_VERSION=$2
            shift
            shift
            ;;
        -n)
            NODES=$2
            shift
            shift
            ;;
        --)
            shift
            break
            ;;
    esac
done

if [ -n "$BINDIR" ]
then
    if [ ! -d $BINDIR ]
    then
        echo "$BINDIR does not exist or it is not a directory"
        exit 1
    fi 
    cd $BINDIR
fi

if [ ! -d $TMPDIR ]
then
    echo "no temp directory found (\$TMPDIR=$TMPDIR)"
    exit 1
fi

if [ -d $TMPDIR/test_sandbox ]
then
    rm -rf $TMPDIR/test_sandbox
    if [ -d $TMPDIR/test_sandbox ]
    then
        echo "can't write to $TMPDIR/test_sandbox"
        exit 1
    fi
fi

mkdir $TMPDIR/test_sandbox
mkdir $TMPDIR/test_sandbox/t
TMPDIR=$TMPDIR/test_sandbox
TEST_DIR=$TMPDIR/t

if [ -x $TSANDBOX/erase_tsandbox ]
then
    $TSANDBOX/erase_tsandbox
fi

SANDBOX_INSTALL_LOG=$TMPDIR/test_sandbox_install_log.txt

for TOPOLOGY in tree direct master-slave all-masters star 'fan-in' tree
do
    FNAME=$TOPOLOGY
    EXTRA=''
    case $TOPOLOGY in
        star)
            EXTRA="--hub=$MAIN_NODE"
            ;;
        tree)
            EXTRA="--tree=2:3"
            TOPOLOGY=master-slave
            ;;
        fan-in)
            EXTRA="--fan-in=$MAIN_NODE"
            ;;
        *)
            EXTRA=''
            ;;
    esac
    # installs the topology
    echo "# tungsten-sandbox -m $MYSQL_VERSION --topology=$TOPOLOGY $EXTRA --nodes=$NODES"
    echo "# tungsten-sandbox -m $MYSQL_VERSION --topology=$TOPOLOGY $EXTRA --nodes=$NODES" > $SANDBOX_INSTALL_LOG 
    tungsten-sandbox -m $MYSQL_VERSION --topology=$TOPOLOGY $EXTRA --nodes=$NODES --verbose >> $SANDBOX_INSTALL_LOG 2>&1
    if [ "$?" != "0" ]
    then 
        cat $SANDBOX_INSTALL_LOG
        exit 1
    fi  
    rm -f $TMPDIR/temp_sandbox_results.txt
    # saves debug info about installation status
    $TSANDBOX/trepctl_all services >> $SANDBOX_INSTALL_LOG
    # runs the sandbox test, and saves it for further processing
    if [ -z "$VERBOSE" ]
    then
        $TSANDBOX/test_topology  >> $TEST_DIR/$FNAME.txt
    else
        $TSANDBOX/test_topology  | tee $TEST_DIR/$FNAME.txt
    fi
    if [ "$?" != "0" ] ; then exit 1 ; fi
    # builds the test script for the current topology
    echo "#!/bin/bash" > $TEST_DIR/$FNAME.t
    echo "cat $TEST_DIR/$FNAME.txt" >> /$TEST_DIR/$FNAME.t
    chmod +x $TEST_DIR/$FNAME.t
    $TSANDBOX/erase_tsandbox > /dev/null 2>&1
done

# Runs all the test scripts at once
# This command will produce the overall test summary
cd $TEST_DIR
PROVE=prove
if [ -z "$VERBOSE" ]
then
    PROVE=prove
else
    PROVE="prove -v"
fi
$PROVE *.t

# echo "ALL TOPOLOGIES TESTED"

