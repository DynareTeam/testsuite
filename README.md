# Dynare's testsuite scripts.

This set of scripts is used to run the Dynare testsuite (integration
and unit tests). The following variables need to be defined in a file
called ```configure.inc``` in the same folder (an example is given in
```configure.inc.example```): ```USER``` (system user which will run
the tests), ```MATLAB_VERSION```, ```MATLAB_PATH``` (the user must be
allowed to run Matlab), ```GIT_REPOSITORY_SSH``` (the user needs to
have an account on Github, or other Git provider, identified by a
valid ssh key), ```GIT_REPOSITORY_HTTP```, ```GIT_BRANCH``` (the
tested branch), ```REMOTE_NAME```, ```REMOTE_PATH```,
```SERVER_PATH```, ```HTTP_PATH```, ```MAILTO```, ```MAILFROM```,
```THREADS``` (the number of threads, should be less than the number of
threads on the server), ```OCTAVE``` (if empty the testsuite is run
with Matlab *and* Octave, if equal to ```--disable-octave``` the
testsuite is only run with Matlab).
