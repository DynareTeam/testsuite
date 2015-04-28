#!/bin/bash

set -ex

LOGFILE=$(mktemp --tmpdir dynare-master-check-XXXXXXXXXX.log)
TMP_DIR=$(mktemp --directory --tmpdir dynare-master-XXXXXXXXXX)
RESULTS_MATLAB=$TMP_DIR/dynare/tests/run_test_matlab_output.txt
RESULTS_OCTAVE=$TMP_DIR/dynare/tests/run_test_octave_output.txt
MATLAB_VERSION=R2014a
LAST_RAN_COMMIT=/home/dynbot/testsuite/last-ran-testsuite-master.txt

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
        ./configure --with-matlab=/usr/local/MATLAB/$MATLAB_VERSION MATLAB_VERSION=$MATLAB_VERSION
        make -j8 all
        # Don't fail at errors in the testsuite
        set +e
	# Run tests (matlab and octave)
        make -C tests -j8 check
	cd tests
	# Copy the generated log files...
	cp --parents `find -name \*.m.log` ../tests.logs.m
	cp --parents `find -name \*.o.log` ../tests.logs.o
	cd ..
	# ... and send them on kirikou.
	rsync -az tests.logs.m/* kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master/matlab
	rsync -az tests.logs.o/* kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master/octave	
	# Write and send footers
	{
	    echo "# Matlab testsuite (master branch)"
	    echo "Commit [$(git log --pretty=format:'%h' -n 1)](https://github.com/DynareTeam/dynare/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
	} > header.md
	pandoc header.md -o header.html
	scp header.html kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master/matlab/header.html
	rm header.*
	{
	    echo "# Octave testsuite (master branch)"
	    echo "Commit [$(git log --pretty=format:'%h' -n 1)](https://github.com/DynareTeam/dynare/commit/$(git log --pretty=format:'%H' -n 1)) by $(git log --pretty=format:'%an' -n 1) [$(git log --pretty=format:'%ad' -n 1)]"
	} > header.md
	pandoc header.md -o header.html
	scp header.html kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master/octave/header.html
	rm header.*
	# Write and send footers
	{
	    echo "Produced by dynbot on karaba $(date)."
	} > footer.md
	pandoc footer.md -o footer.html
	scp footer.html kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master/matlab/footer.html
	scp footer.html kirikou.cepremap.org:/srv/d_kirikou/www.dynare.org/testsuite/master/octave/footer.html
	rm footer.*
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
        echo "A full log can be found at http://www.dynare.org/testsuite/master"
    } | mail -s "Status of testsuite in master branch" dev@dynare.org -aFrom:"Dynare Robot <dynbot@dynare.org>"
fi

rm -rf $TMP_DIR
