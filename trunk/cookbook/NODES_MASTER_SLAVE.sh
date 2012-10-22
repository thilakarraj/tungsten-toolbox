#!/bin/bash

export NODE1=
export NODE2=
export NODE3=
export NODE4=

export ALL_NODES=($NODE1 $NODE2 $NODE3 $NODE4)
# indicate which servers will be masters, and which ones will have a slave service
# in case of all-masters topologies, these two arrays will be the same as $ALL_NODES
# These values are used for automated testing

#for master/slave replication
export MASTERS=($NODE1)
export SLAVES=($NODE2 $NODE3 $NODE4)


