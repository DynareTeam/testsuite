#!/bin/sh

set -ex

TESTSUITE_CODE_PATH=/home/houtanb/TESTSUITE/testsuite
CSVPATH=/home/houtanb/TESTSUITE/testSuiteTiming
ORIGPATH=$PWD
DATE=`date +%Y%m%d`

if [ ! -d $CSVPATH ]
then
    mkdir $CSVPATH
fi

# Write timing from .trs files to .csv files from previous test runs
cd $1
SHA=`git rev-parse HEAD`
TRS_FILES=`find . -regex ".*\.\(trs\)" | sed 's/\.\///'`
for file in $TRS_FILES; do
    time=`grep cputime $file | cut -d: -f3 | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'`
    csvfile=`echo $file | sed 's/\//-/g' | sed 's/\.trs$/\.csv/g'`
    if [ ! -f $CSVPATH/$csvfile ]; then
        name=`echo $file | sed 's/\.m\.trs$/.mod/g' | sed 's/\.o\.trs$/.mod/g'`
        echo "Date,$name,SHA" > $CSVPATH/$csvfile
    fi
    echo $DATE,$time,$SHA >> $CSVPATH/$csvfile
done

# Create html file for graphs
cd $CSVPATH
python $TESTSUITE_CODE_PATH/timing.py
cd $ORIGPATH

