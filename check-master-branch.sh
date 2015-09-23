#!/bin/bash

set -ex

# Set user name (default value)
USER=dynbot

# Set variables for matlab location (default values)
MATLAB_VERSION=R2014a
MATLAB_PATH=/usr/local/MATLAB

# Set branch name (default value)
GIT_BRANCH=master
 
# Set git repository (default value)
GIT_REPOSITORY_SSH=git@github.com:DynareTeam/dynare.git
GIT_REPOSITORY_HTTP=https://github.com/DynareTeam/dynare

# Set variables related to the publication of the results (default values)
REMOTE_NAME=kirikou.cepremap.org
REMOTE_PATH=/srv/d_kirikou/www.dynare.org/testsuite/$GIT_BRANCH
SERVER_PATH=$REMOTE_NAME:$REMOTE_PATH
HTTP_PATH=http://www.dynare.org/testsuite/$GIT_BRANCH
MAILTO=dev@dynare.org
MAILFROM=dynbot@dynare.org

# Set the number of threads to be used by make (default value)
THREADS=8

# Set option for disabling Octave (empty by default)
OCTAVE=

# Set path to testsuite's code.
TESTSUITE_CODE_PATH=$(dirname $(realpath -s $0))

# Change default values for the previous variables
if [ -f  $TESTSUITE_CODE_PATH/configure.inc ]
  then
    source $TESTSUITE_CODE_PATH/configure.inc
fi

# Set paths for Dynare and test folder
LOGFILE=$(mktemp --tmpdir dynare-$GIT_BRANCH-check-XXXXXXXXXX.log)
TMP_DIR=$(mktemp --directory --tmpdir dynare-$GIT_BRANCH-XXXXXXXXXX)

# Define the name of the txt file where a testsuite summary will be written (matlab)
RESULTS_MATLAB=$TMP_DIR/dynare/tests/run_test_matlab_output.txt

# Define the name of the txt file where a testsuite summary will be written (octave)
RESULTS_OCTAVE=$TMP_DIR/dynare/tests/run_test_octave_output.txt

# Name of the file containing the hash of the HEAD commit considered in the previous run of the testsuite. 
LAST_RAN_COMMIT=$TESTSUITE_CODE_PATH/last-ran-testsuite-$GIT_BRANCH.txt

{
    cd $TMP_DIR
    git clone --depth 1 --recursive --branch $GIT_BRANCH --single-branch $GIT_REPOSITORY_SSH
    cd dynare
    COMMIT=$(git log -1 --pretty=oneline HEAD)
    if [[ -f $LAST_RAN_COMMIT && "$(cat $LAST_RAN_COMMIT)" == "$(echo $COMMIT)" ]]; then
        RUN_TESTSUITE=0
    else
        RUN_TESTSUITE=1
        echo $COMMIT > $LAST_RAN_COMMIT
	# Compile binaries (preprocessor and mex files)
        autoreconf -i -s
        ./configure  --with-matlab=$MATLAB_PATH/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION $OCTAVE
        make -j$THREADS all
        # Don't fail at errors in the testsuite
        set +e
	# Run tests (matlab and octave)
        make -C tests -j$THREADS check
	cd $TMP_DIR/dynare/tests
	# Copy the generated log files...
	mkdir $TMP_DIR/dynare/tests.logs.m
        cp --parents `find -name \*.m.log` $TMP_DIR/dynare/tests.logs.m/
        if [ -z $OCTAVE ]
           then
	       mkdir $TMP_DIR/dynare/tests.logs.o
               cp --parents `find -name \*.o.log` $TMP_DIR/dynare/tests.logs.o/
        fi
	# ... and send them on kirikou.
	ssh $REMOTE_NAME mkdir -p $REMOTE_PATH/matlab
	ssh $REMOTE_NAME rm -rf $REMOTE_PATH/matlab/*
	rsync -az $TMP_DIR/dynare/tests.logs.m/* $SERVER_PATH/matlab
        if [ -z $OCTAVE ]
            then
		ssh $REMOTE_NAME mkdir -p $REMOTE_PATH/octave
		ssh $REMOTE_NAME rm -rf $REMOTE_PATH/octave/*
		rsync -az $TMP_DIR/dynare/tests.logs.o/* $SERVER_PATH/octave
        fi
        # Write and send footers
	{
	    echo "# Matlab testsuite ("$GIT_BRANCH "branch)"
	    echo "Last commit [$(git log --pretty=format:'%h' -n 1)]($GIT_REPOSITORY_HTTP/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
	} > header.md
	pandoc header.md -o header.html
	scp header.html $SERVER_PATH/matlab/header.html
	rm header.*
        if [ -z $OCTAVE ]
           then
	       {
	           echo "# Octave testsuite ("$GIT_BRANCH "branch)"
	           echo "Last commit [$(git log --pretty=format:'%h' -n 1)]($GIT_REPOSITORY_HTTP/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
	       } > header.md
	       pandoc header.md -o header.html
	       scp header.html $SERVER_PATH/octave/header.html
	       rm header.*
        fi
	# Write and send footers
	{
	    echo "Produced by $USER on $(hostname) $(date)."
	} > footer.md
	pandoc footer.md -o footer.html
	scp footer.html $SERVER_PATH/matlab/footer.html
        if [ -z $OCTAVE ]
           then
	       scp footer.html $SERVER_PATH/octave/footer.html
        fi
	rm footer.*
	cat $LOGFILE | $TESTSUITE_CODE_PATH/ansi2html.sh > footer.html
	scp footer.html $SERVER_PATH/footer.html
	rm footer.html
	# Build archive containing all the logs
	tar -jcvf matlablogs.tar.bz2 $TMP_DIR/dynare/tests.logs.m
        if [ -z $OCTAVE ]
           then
	       tar -jcvf octavelogs.tar.bz2 $TMP_DIR/dynare/tests.logs.m
        fi
	scp *.tar.bz2 $SERVER_PATH
	# Update timing, create index, copy to kirikou
	ssh $REMOTE_NAME mkdir -p $REMOTE_PATH/timing/
	ssh $REMOTE_NAME rm -rf $REMOTE_PATH/timing/*
        $TESTSUITE_CODE_PATH/timing-and-html-file.sh $TMP_DIR/dynare/tests
        scp $TESTSUITE_CODE_PATH/../testSuiteTiming/* $SERVER_PATH/timing/
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
        if [ -z $OCTAVE ]
           then
               cat $RESULTS_OCTAVE || echo -e "Dynare failed to compile or Octave testsuite failed to run\n"
        else
            echo "Did not run the testsuite for Octave"
        fi
        echo "A full log can be found at" $HTTP_PATH
    } | mail -s "Status of testsuite in $GIT_BRANCH branch" $MAILTO -aFrom:"Dynare Robot <"$MAILFROM">"
fi
