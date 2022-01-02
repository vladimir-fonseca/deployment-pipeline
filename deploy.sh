#!/bin/bash

set -e -x
# trap - SIGINT SIGQUIT SIGTSTP

source functions.sh

export TF_VAR_chdir="./remote-state"

cd ${TF_VAR_chdir}

if [ ! -e backend.tf ] && [ ! -e env_backend.sh ] 
then
    terraform init -input=false
    tf_apply
    source env_backend.sh 
    backend_s3
    tf_init_s3
else
    source env_backend.sh
    tf_init_s3
fi

tf_apply
cd ..

export TF_VAR_chdir="./codepipeline"
export TF_VAR_backend_key="codepipeline.tfstate"
cd ${TF_VAR_chdir}
if [ ! -e backend.tf ] && [ ! -e env_backend.sh ] 
then
    backend_s3
    tf_init_s3
else
    tf_init_s3
fi

tf_apply
cd ..
