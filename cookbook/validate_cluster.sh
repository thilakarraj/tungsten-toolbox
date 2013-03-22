#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.4 - 2013-03-07

[ -z "$VERBOSE" ]  && export VERBOSE=1
export VALIDATE_ONLY=1
COOKBOOK_DIR=$(dirname $0)

if [ -f CURRENT_TOPOLOGY ]
then
    echo "There is already a topology installed : `cat CURRENT_TOPOLOGY`"
    echo "The purpose of this script is to check the cluster before installation "
    echo "to make sure that you can install"
    echo ""
    echo "Syntax: [VERBOSE=2] $0"
    echo ""
    echo "If VERBOSE=2 is used, you will get all the gory details of what Tungsten is checking"
    exit 1
fi


if [ -f $COOKBOOK_DIR/install_master_slave.sh ]
then
    $COOKBOOK_DIR/install_master_slave.sh
else
    echo "$COOKBOOK_DIR/install_master_slave.sh not found"
    exit 1
fi

