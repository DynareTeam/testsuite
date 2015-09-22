#!/bin/sh

TESTSUITE_CODE_PATH=$(dirname $(realpath -s $0))
CSVPATH=$(realpath $TESTSUITE_CODE_PATH/../testSuiteTiming)
HTML=$CSVPATH/index.html
ORIGPATH=$PWD
DATE=`date +%Y%m%d`

if [ ! -d $CSVPATH ]
then
    mkdir $CSVPATH
fi

# Write timing from .trs files to .csv files from previous test runs
cd $1
TRS_FILES=`find . -regex ".*\.\(trs\)" | sed 's/\.\///'`
for file in $TRS_FILES; do
    time=`grep cputime $file | cut -d: -f3 | sed -e 's/^[[:space:]]*//' | sed -e 's/[[:space:]]*$//'`
    csvfile=`echo $file | sed 's/\//-/g' | sed 's/\.trs$/\.csv/g'`
    if [ ! -f $CSVPATH/$csvfile ]; then
        name=`echo $file | sed 's/\.m\.trs$/.mod/g' | sed 's/\.o\.trs$/.mod/g'`
        echo "DATE,$name" > $CSVPATH/$csvfile
    fi
    echo $DATE,$time >> $CSVPATH/$csvfile
done

# Create html file for graphs
cd $CSVPATH
echo "<html>"     > $HTML
echo "<head>"    >> $HTML
echo "<script type=\"text/javascript\" src=\"http://cdnjs.cloudflare.com/ajax/libs/dygraph/1.1.0/dygraph-combined.js\"></script>"    >> $HTML
echo "</head>"   >> $HTML
echo "<body>"    >> $HTML

COUNTER=1
for file in *.csv
do
    title=`echo $file | sed -e 's/-/\//' | sed 's/\.o\.csv/\.mod/g' | sed 's/\.m\.csv/\.mod/g'`
    echo "<div id=\"graphdiv$COUNTER\" style=\"width:600px; height:180px;\"></div>" >> $HTML
    echo "<script type=\"text/javascript\">"                                        >> $HTML
    echo " g$COUNTER = new Dygraph("                                                >> $HTML
    echo "    document.getElementById(\"graphdiv$COUNTER\"),"                       >> $HTML
    echo "    \"$file\","              >> $HTML
    echo "    {"                       >> $HTML
    echo "     ylabel: 'cputime',"     >> $HTML
    echo "     title: '$title',"       >> $HTML
    echo "    }"                       >> $HTML
    echo " );"                         >> $HTML
    echo "</script>"                   >> $HTML
    COUNTER=$((COUNTER + 1))
done

echo "</body>"    >> $HTML
echo "</html>"    >> $HTML

cd $ORIGPATH
