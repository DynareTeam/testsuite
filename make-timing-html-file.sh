#!/bin/sh

TESTSUITE_CODE_PATH=$(dirname $(realpath -s $0))
CSVPATH=$(realpath $TESTSUITE_CODE_PATH/../testSuiteTiming)
HTML=$CSVPATH/index.html

ORIGPATH=$PWD

if [ ! -d $CSVPATH ]
then
    mkdir $CSVPATH
fi
    
cd $CSVPATH

if [ ! -f $HTML]
then
    touch $HTML
fi

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
