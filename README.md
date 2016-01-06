# Dynare's testsuite scripts.

This set of scripts is used to run the Dynare testsuite (integration
and unit tests). The following variables need to be defined in a file
called ```configure.inc``` in the same folder (an example is given in
```configure.inc.example```): ```USER``` (system user which will run
the tests), ```MATLAB``` (equal to true or false), ```OCTAVE``` (equal
to true or false), ```MATLAB_VERSION```, ```MATLAB_PATH``` (the user
must be allowed to run Matlab), ```OCTAVE_PATH```,
```GIT_REPOSITORY_SSH``` (the user needs to have an account on Github,
or other Git provider, identified by a valid ssh key),
```GIT_REPOSITORY_HTTP```, ```GIT_BRANCH``` (the tested branch),
```REMOTE_NAME```, ```REMOTE_PATH```, ```SERVER_PATH```,
```HTTP_PATH```, ```MAILTO```, ```MAILFROM```, ```THREADS``` (the
number of threads, should be less than the number of threads on the
server).

The testsuite is run with Matlab if and only if ```MATLAB``` value is
true. The testsuite is run with Octave if and only if ```OCTAVE```
value is true. The path to Matlab has only to be provided if
```MATLAB```is true. The path to Octave is not mandatory, the binary
installed by the package manager is used by default.
