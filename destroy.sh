#!/bin/bash

set -e -x

source functions.sh

source remote-state/env_backend.sh
EXIT_CODE=0

export TF_VAR_chdir="./codepipeline"
cd ${TF_VAR_chdir}
tf_destroy || true
destroy_all
cd ..

export TF_VAR_chdir="./remote-state"

cd ${TF_VAR_chdir}

tf_destroy || true
destroy_all

cd ..