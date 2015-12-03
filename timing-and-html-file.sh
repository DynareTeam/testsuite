#!/bin/sh

set -ex

ORIGPATH=$PWD
DATE=`date +%Y%m%d`

if [ ! -d $TESTSUITE_TIMING_PATH ]
then
    mkdir $TESTSUITE_TIMING_PATH
fi

# Write timing from .trs files to .csv files from previous test runs
cd $1
SHA=`git rev-parse HEAD`
TRS_FILES=`find . -regex ".*\.\(trs\)" | sed 's/\.\///'`
echo $TRS_FILES
for file in $TRS_FILES; do
    time=`grep cputime $file | cut -d: -f3 | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'`

    path=`dirname $file`
    mkdir -p $TESTSUITE_TIMING_PATH/$path

    trsfile=`basename $file`
    csvfile=`echo $trsfile | sed 's/\.trs$/\.csv/g'`
    echo $path/$trsfile
    echo $path/$csvfile
    if [ ! -f $TESTSUITE_TIMING_PATH/$path/$csvfile ]; then
        name=`echo $file | sed 's/\.m\.trs$/.mod/g' | sed 's/\.o\.trs$/.mod/g'`
        echo "Date,$name,SHA" > $TESTSUITE_TIMING_PATH/$path/$csvfile
    fi
    echo $DATE,$time,$SHA >> $TESTSUITE_TIMING_PATH/$path/$csvfile
done

# Create html file for graphs
CSVFILES=`find $TESTSUITE_TIMING_PATH -name "*.csv"`
echo $CSVFILES
for file in $CSVFILES; do
    echo $file
    filedate=`awk '/./{line=$0} END{print line}' $file | cut -d ',' -f 1 | tr -d '[[:space:]]'`
    if [ $DATE -ne $filedate ]; then
        echo $DATE,"NaN",$SHA >> $file
    fi
done

find $TESTSUITE_TIMING_PATH -type d -exec sh -c '(cd {} && python $TESTSUITE_CODE_PATH/make_timing_graphs.py)' ';'
