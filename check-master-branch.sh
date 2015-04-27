#!/bin/bash

# WARNING: this script mirrors from kirikou. In particular, when a new stable
# branch is created, the mirroring script on kirikou needs a manual update.

set -ex

LOGFILE=$(mktemp --tmpdir dynare-master-check-XXXXXXXXXX.log)
TMP_DIR=$(mktemp --directory --tmpdir dynare-master-XXXXXXXXXX)
RESULTS_MATLAB=$TMP_DIR/dynare/tests/run_test_matlab_output.txt
RESULTS_OCTAVE=$TMP_DIR/dynare/tests/run_test_octave_output.txt
MATLAB_VERSION=R2014a
LAST_RAN_COMMIT=/home/dynbot/last-ran-testsuite-master.txt

{
    cd $TMP_DIR
    git clone http://www.dynare.org/git/dynare.git
    cd dynare
    COMMIT=$(git log -1 --pretty=oneline HEAD)
    if [[ -f $LAST_RAN_COMMIT && "$(cat $LAST_RAN_COMMIT)" == "$(echo $COMMIT)" ]]; then
        RUN_TESTSUITE=0
    else
        RUN_TESTSUITE=1
        echo $COMMIT > $LAST_RAN_COMMIT
        git submodule update --init
        autoreconf -i -s
        ./configure --with-matlab=/usr/local/MATLAB/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION
        make -j5 all
        # Don't fail at errors in the testsuite
        set +e
        make -C tests -j8 check
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
        echo "A full log can be found on karaba in '$LOGFILE'."
    } | mail -s "Status of testsuite in master branch" dev@dynare.org -aFrom:"Dynare Robot <dynbot@dynare.org>"
#-- -f "Dynare Robot <dynbot@dynare.org>"
fi

rm -rf $TMP_DIR





git clone --depth 1 --recursive --branch 4.4 --single-branch git@github.com:DynareTeam/dynare.git
