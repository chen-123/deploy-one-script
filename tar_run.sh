#!/bin/bash
[ -f run-v1.0.tar.gz ] && rm -f run-v1.0.tar.gz

\cp *.sh pkg/run/v1.0
 
tar cvf run-v1.0.tar.gz pkg/run/v1.0
