#!/bin/bash

set -ex

TESTSUITE_CODE_PATH=$(dirname $(realpath -s $0))
LAST_RAN_COMMIT=$TESTSUITE_CODE_PATH/last-ran-testsuite-master.txt

# Set paths for Dynare and tests
LOGFILE=$(mktemp --tmpdir dynare-master-check-XXXXXXXXXX.log)
TMP_DIR=$(mktemp --directory --tmpdir dynare-master-XXXXXXXXXX)
RESULTS_MATLAB=$TMP_DIR/dynare/tests/run_test_matlab_output.txt
RESULTS_OCTAVE=$TMP_DIR/dynare/tests/run_test_octave_output.txt

# Set user name
USER=dynbot

# Set variables for matlab location
MATLAB_VERSION=R2014a
MATLAB_PATH=/usr/local/MATLAB

# Set variables related to the publication of the results
SERVER_PATH=kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master
HTTP_PATH=http://www.dynare.org/testsuite/master
MAILTO=dev@dynare.org
MAILFROM=dynbot@dynare.org

# Set the number of threads to be used by make
THREADS=8

#


{
    cd $TMP_DIR
    git clone --depth 1 --recursive --branch master --single-branch git@github.com:DynareTeam/dynare.git
    cd dynare
    COMMIT=$(git log -1 --pretty=oneline HEAD)
    if [[ -f $LAST_RAN_COMMIT && "$(cat $LAST_RAN_COMMIT)" == "$(echo $COMMIT)" ]]; then
        RUN_TESTSUITE=0
    else
        RUN_TESTSUITE=1
        echo $COMMIT > $LAST_RAN_COMMIT
	# Compile binaries (preprocessor and mex files)
        autoreconf -i -s
        ./configure --with-matlab=$MATLAB_PATH/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION
        make -j$THREADS all
        # Don't fail at errors in the testsuite
        set +e
	# Run tests (matlab and octave)
        make -C tests -j$THREADS check
	cd $TMP_DIR/dynare/tests
	# Copy the generated log files...
	mkdir $TMP_DIR/dynare/tests.logs.m
	mkdir $TMP_DIR/dynare/tests.logs.o
	cp --parents `find -name \*.m.log` $TMP_DIR/dynare/tests.logs.m/
	cp --parents `find -name \*.o.log` $TMP_DIR/dynare/tests.logs.o/
	$TMP_DIR/dynare
	# ... and send them on kirikou.
	rsync -az $TMP_DIR/dynare/tests.logs.m/* $SERVER_PATH/matlab
	rsync -az $TMP_DIR/dynare/tests.logs.o/* $SERVER_PATH/octave
	# Write and send footers
	{
	    echo "# Matlab testsuite (master branch)"
	    echo "Last commit [$(git log --pretty=format:'%h' -n 1)](https://github.com/DynareTeam/dynare/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
	} > header.md
	pandoc header.md -o header.html
	scp header.html $SERVER_PATH/matlab/header.html
	rm header.*
	{
	    echo "# Octave testsuite (master branch)"
	    echo "Last commit [$(git log --pretty=format:'%h' -n 1)](https://github.com/DynareTeam/dynare/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
	} > header.md
	pandoc header.md -o header.html
	scp header.html $SERVER_PATH/octave/header.html
	rm header.*
	# Write and send footers
	{
	    echo "Produced by $USER on $(hostname) $(date)."
	} > footer.md
	pandoc footer.md -o footer.html
	scp footer.html $SERVER_PATH/matlab/footer.html
	scp footer.html $SERVER_PATH/octave/footer.html
	rm footer.*
	cat $LOGFILE | $TESTSUITE_CODE_PATH/ansi2html.sh > footer.html
	scp footer.html $SERVER_PATH/footer.html
	rm footer.html
	# Build archive containing all the logs
	tar -jcvf matlablogs.tar.bz2 $TMP_DIR/dynare/tests.logs.m
	tar -jcvf octavelogs.tar.bz2 $TMP_DIR/dynare/tests.logs.m
	scp *.tar.bz2 $SERVER_PATH
        set -e
    fi
} >$LOGFILE 2>&1

if [[ $RUN_TESTSUITE == 0 ]]; then
    rm -f $LOGFILE
else
    chmod +r $LOGFILE
    {
        cd $TMP_DIR/dynare && git log -1 --pretty=oneline HEAD
        echo
        cat $RESULTS_MATLAB || echo -e "Dynare failed to compile or MATLAB testsuite failed to run\n"
        cat $RESULTS_OCTAVE || echo -e "Dynare failed to compile or Octave testsuite failed to run\n"
        echo "A full log can be found at" $HTTP_PATH
    } | mail -s "Status of testsuite in master branch" $MAILTO -aFrom:"Dynare Robot <"$MAILFROM">"
fi

#rm -rf $TMP_DIR
