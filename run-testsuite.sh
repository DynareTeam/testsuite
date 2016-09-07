#!/bin/bash
TERM=xterm-256color
export TERM

set -ex

# Set path to testsuite's code.
TESTSUITE_CODE_PATH=$(dirname $(realpath -s $0))

# Set path to testsuite's timings.
TESTSUITE_TIMING_PATH=$(realpath -s $TESTSUITE_CODE_PATH/../testSuiteTiming)

# Set a default value for the number of threads
THREADS=1

# Change default values for the previous variables
if [ -f  $TESTSUITE_CODE_PATH/configure.inc ]
then
    source $TESTSUITE_CODE_PATH/configure.inc
fi

# Check input values correctly set
if $PUBLISH_RESULTS ; then
    if [[ -z $REMOTE_NAME || -z $REMOTE_PATH || -z $SERVER_PATH ]]; then
        echo 'You want to publish the results of the test suite but have not set one of ' \
             'REMOTE_NAME, REMOTE_PATH, SERVER_PATH'
        exit 1
    fi
fi

if $EMAIL_RESULTS ; then
    EXIT=false
    if [[ -z $MAILTO || -z $MAILFROM ]]; then
        VARS='MAILTO, MAILFROM'
        EXIT=true
    fi
    if $PUBLISH_RESULTS ; then
	if [[ -z $HTTP_PATH ]]; then
            VARS="$VARS, HTTP_PATH"
            EXIT=true
	fi
    fi
    if $EXIT ; then
        echo 'You want to publish the results of the test suite but have not set one of ' $VARS
        exit 1
    fi
fi

# Set paths for Dynare and test folder
LOGFILE=$(mktemp --tmpdir dynare-$GIT_BRANCH-check-XXXXXXXXXX.log)
TMP_DIR=$(mktemp --directory --tmpdir dynare-$GIT_BRANCH-XXXXXXXXXX)

# Define the name of the txt file where a testsuite summary will be written (matlab)
if $MATLAB
   then
       RESULTS_MATLAB=$TMP_DIR/dynare/tests/run_test_matlab_output.txt
fi

# Define the name of the txt file where a testsuite summary will be written (matlab)
if $OCTAVE
    then
        RESULTS_OCTAVE=$TMP_DIR/dynare/tests/run_test_octave_output.txt
fi

if ! $MATLAB && ! $OCTAVE ; then
    echo "MATLAB and OCTAVE variables are false => There is nothing to do, I quit!"
    exit
fi

# Name of the file containing the hash of the HEAD commit considered in the previous run of the testsuite.
LAST_RAN_COMMIT=$TESTSUITE_CODE_PATH/last-ran-testsuite-$GIT_BRANCH.txt

{
    cd $TMP_DIR
    #don't fail if git clone ssh didn't work
    set +e
    git clone --depth 1 --recursive --branch $GIT_BRANCH --single-branch $GIT_REPOSITORY_SSH
    set -e
    if [ ! -d "dynare" ]; then
        git clone --depth 1 --recursive --branch $GIT_BRANCH --single-branch $GIT_REPOSITORY_HTTP
    fi
    cd dynare
    COMMIT=$(git log -1 --pretty=oneline HEAD)
    if [[ (-v FORCE && $FORCE != true) && -f $LAST_RAN_COMMIT && "$(cat $LAST_RAN_COMMIT)" == "$(echo $COMMIT)" ]]; then
        RUN_TESTSUITE=0
    else
        RUN_TESTSUITE=1
        echo $COMMIT > $LAST_RAN_COMMIT
        # Compile binaries (preprocessor and mex files)
        autoreconf -i -s
        if $MATLAB && $OCTAVE ; then
	    if [[ -v OCTAVE_PATH ]] ; then
		./configure  --with-matlab=$MATLAB_PATH/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION --with-octave=$OCTAVE_PATH;
	    else
		./configure  --with-matlab=$MATLAB_PATH/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION ;
	    fi
        elif $MATLAB && ! $OCTAVE ; then
            ./configure  --with-matlab=$MATLAB_PATH/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION --disable-octave ;
        else
	    if [[ -v OCTAVE_PATH ]] ; then
		./configure --with-octave=$OCTAVE_PATH ;
	    else
		./configure
	    fi
        fi
        make -j$THREADS all
        # Don't fail at errors in the testsuite
        set +e
        # Run tests (matlab and octave)
        cd $TMP_DIR/dynare/tests
        if $OCTAVE && $MATLAB ; then
            make -j$THREADS check
        elif ! $OCTAVE ; then
            make -j$THREADS check-matlab
        elif ! $MATLAB ; then
            make -j$THREADS check-octave
        fi
        # Copy the generated log files...
        if $MATLAB ; then
            mkdir $TMP_DIR/dynare/tests.logs.m
            cp --parents `find -name \*.m.log` $TMP_DIR/dynare/tests.logs.m/
        fi
        if $OCTAVE ; then
            mkdir $TMP_DIR/dynare/tests.logs.o
            cp --parents `find -name \*.o.log` $TMP_DIR/dynare/tests.logs.o/
        fi
        # Update timing ...
        TESTSUITE_CODE_PATH=$TESTSUITE_CODE_PATH TESTSUITE_TIMING_PATH=$TESTSUITE_TIMING_PATH \
                             $TESTSUITE_CODE_PATH/timing-and-html-file.sh $TMP_DIR/dynare/tests
        # ... and if we want to publish the results, send them to the server
        if $PUBLISH_RESULTS ; then
           if $MATLAB ; then
               ssh $REMOTE_NAME mkdir -p $REMOTE_PATH/matlab
               ssh $REMOTE_NAME rm -rf $REMOTE_PATH/matlab/*
               rsync -az $TMP_DIR/dynare/tests.logs.m/* $SERVER_PATH/matlab
           fi
           if $OCTAVE ; then
               ssh $REMOTE_NAME mkdir -p $REMOTE_PATH/octave
               ssh $REMOTE_NAME rm -rf $REMOTE_PATH/octave/*
               rsync -az $TMP_DIR/dynare/tests.logs.o/* $SERVER_PATH/octave
           fi
           # Write and send footers
           if $MATLAB ; then
               {
                   echo "# Matlab testsuite ("$GIT_BRANCH "branch)"
                   echo "Last commit [$(git log --pretty=format:'%h' -n 1)]($GIT_REPOSITORY_HTTP/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
               } > header.md
               pandoc header.md -o header.html
               scp header.html $SERVER_PATH/matlab/header.html
               rm header.*
           fi
           if $OCTAVE ; then
               {
                   echo "# Octave testsuite ("$GIT_BRANCH "branch)"
                   echo "Last commit [$(git log --pretty=format:'%h' -n 1)]($GIT_REPOSITORY_HTTP/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
               } > header.md
               pandoc header.md -o header.html
               scp header.html $SERVER_PATH/octave/header.html
               rm header.*
           fi
           # Write and send footers
           echo "\n\nProduced by $USER on $(hostname) $(date)." > footer-date
           cat $LOGFILE footer-date > footer
           cat footer | $TESTSUITE_CODE_PATH/ansi2html.sh > footer.html
           if $OCTAVE && $MATLAB ; then
               scp footer.html $SERVER_PATH/footer.html ;
           elif $OCTAVE ; then
               scp footer.html $SERVER_PATH/octave/footer.html ;
           elif $MATLAB ; then
               scp footer.html $SERVER_PATH/matlab/footer.html ;
           else
               echo "I should not be on this branch..."
               exit
           fi
           # Build archive containing all the logs
           if $MATLAB ; then
               tar -jcvf matlablogs.tar.bz2 $TMP_DIR/dynare/tests.logs.m
           fi
           if $OCTAVE ; then
               tar -jcvf octavelogs.tar.bz2 $TMP_DIR/dynare/tests.logs.o
           fi
           scp *.tar.bz2 $SERVER_PATH
           ssh $REMOTE_NAME mkdir -p $REMOTE_PATH/timing
           ssh $REMOTE_NAME rm -rf $REMOTE_PATH/timing/*
           ORIGPATH=$PWD
           cd $TESTSUITE_TIMING_PATH
           rsync -rav -e ssh --include '*/' --include='*.html' --exclude='*' ./ $SERVER_PATH/timing/
           cd $ORIGPATH
           set -e
        fi
    fi
} >$LOGFILE 2>&1

if [[ $RUN_TESTSUITE == 0 ]]; then
    rm -f $LOGFILE
else
    chmod +r $LOGFILE
    if $EMAIL_RESULTS ; then
       {
           cd $TMP_DIR/dynare && git log -1 --pretty=oneline HEAD
           if $MATLAB ; then
               cat $RESULTS_MATLAB || echo -e "Dynare failed to compile or MATLAB testsuite failed to run\n"
           fi
           if $OCTAVE ; then
               cat $RESULTS_OCTAVE || echo -e "Dynare failed to compile or Octave testsuite failed to run\n"
           fi
           if $PUBLISH_RESULTS ; then
              if $MATLAB && $OCTAVE ; then
                  echo "A full log can be found at $HTTP_PATH"
		  echo "Run on Matlab $MATLAB_VERSION and Octave `octave -v | head -1`, `uname -a`"
              fi
              if $MATLAB && ! $OCTAVE ; then
                  echo "A full log can be found at $HTTP_PATH/matlab"
		  echo "Run on Matlab $MATLAB_VERSION, `uname -a`"
              fi
              if $OCTAVE && ! $MATLAB ; then
                  echo "A full log can be found at $HTTP_PATH/octave"
		  echo "Run on Octave `octave -v | head -1`, `uname -a`"
              fi
           fi
       } | mail -s "Status of testsuite (sedna) on $GIT_BRANCH branch" $MAILTO -aFrom:"Dynare Robot <"$MAILFROM">"
    fi
fi
