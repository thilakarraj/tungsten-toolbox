#!/bin/bash
# (C) Copyright 2012 Continuent, Inc - Released under the New BSD License
# Version 1.0.3 - 2012-11-19

if [ ! -f tungsten-replicator-cookbook.tar.gz ]
then
    echo "could not find tungsten-replicator-cookbook.tar.gz "
    exit 1
fi

if [ ! -x ./tools/tungsten-installer ]
then
    echo "cannot find ./tools/tungsten-installer"
    echo "this deployer must run inside an expanded tungsten-replicator tarball"
    exit 1
fi

if [ -d ./cookbook ]
then
    echo "directory 'cookbook' already exists"
    echo "remove or rename it and then run the deployer again"
    exit 1
fi


tar -xzf tungsten-replicator-cookbook.tar.gz 

if [ ! -d ./cookbook ]
then
    echo "Incorrect deployment. The directory 'cookbook' was not created"
    exit 1
fi

ls cookbook

echo "please read ./cookbook/README"

