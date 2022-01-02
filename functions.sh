#!/bin/bash
#

set -e -x
# trap - SIGINT SIGQUIT SIGTSTP

function tf_init_s3 {

    echo "yes" | TF_INPUT="true"                                               \
        terraform init -upgrade=true                                           \
            -backend=true                                                      \
            -backend-config="bucket=${TF_VAR_backend_bucket}"                   \
            -backend-config="acl=${TF_VAR_backend_acl}"                         \
            -backend-config="region=${TF_VAR_backend_region}"                   \
            -backend-config="encrypt=${TF_VAR_backend_encrypt}"                 \
            -backend-config="dynamodb_table=${TF_VAR_backend_dynamodb_table}"   \
            -backend-config="key=${TF_VAR_backend_key}"                         \
            -force-copy                                                        \
            -get=true                                                          \
            -reconfigure=true                                                   \
            -upgrade=true                                                      
            
}

function backend_s3 {

    tee backend.tf <<BACKEND
terraform {
backend "s3" {
    bucket         = "${TF_VAR_backend_bucket}"
    acl            = "${TF_VAR_backend_acl}"
    region         = "${TF_VAR_backend_region}"
    encrypt        = "${TF_VAR_backend_encrypt}"
    dynamodb_table = "${TF_VAR_backend_dynamodb_table}"
    key            = "${TF_VAR_backend_key}"
  }
}
BACKEND

}

function lower_level_remote_state {

    tee -a lowerlevel_data_remote_state.tf <<DATA_REMOTE_STATE
data "terraform_remote_state" "${TF_VAR_lowerlevel_chdir}" {
    backend             = "s3"
    workspace           = "${TF_VAR_lowerlevel_workspace}"
    
    config = {
        bucket          = "${TF_VAR_lowerlevel_backend_bucket}"
        acl             = "${TF_VAR_lowerlevel_backend_acl}"
        region          = "${TF_VAR_lowerlevel_backend_region}"
        encrypt         = "${TF_VAR_lowerlevel_backend_encrypt}"
        dynamodb_table  = "${TF_VAR_lowerlevel_backend_dynamodb_table}"
        key             = "${TF_VAR_lowerlevel_backend_key}"
    }
}

DATA_REMOTE_STATE

}

function tf_apply {
    if [ -z ${TF_VAR_landingzone_var_file} ]
    then
        terraform apply                                 \
            -input=false -auto-approve  
    elif 
        [ ! -z ${TF_VAR_landingzone_extra_var_file} ]
    then
        terraform apply                                 \
            -input=false -auto-approve                  \
            -var-file=${TF_VAR_landingzone_var_file}      \
            -var-file=${TF_VAR_landingzone_extra_var_file}
    else
        terraform apply                                 \
            -input=false -auto-approve                  \
            -var-file=${TF_VAR_landingzone_var_file}
            
    fi

    # git operations
    # git add .
    # git commit -a -m "${TF_VAR_level} ${TF_VAR_landingzone} Deployed" || COMMIT_STATE=$?
    # if [[ $COMMIT_STATE -eq 0 ]]
    # then
    #     git push origin
    #     git pull
    # fi
    
}

function create_workspace {

    terraform workspace select default || true
    terraform workspace delete ${TF_VAR_workspace} || true
    terraform workspace new ${TF_VAR_workspace} || true
    terraform workspace select ${TF_VAR_workspace} || true
    echo $?
    
}

function select_workspace {
    terraform workspace select ${TF_VAR_workspace} || true
}

function apply_level {

    if [ ! -e backend.tf ] 
    then
        backend_s3
        [ ! -e lowerlevel_data_remote_state.tf ] && lower_level_remote_state
        tf_init_s3
        echo "create workspace"
        create_workspace
        # export TF_WORKSPACE=${TF_VAR_workspace}
        tf_init_s3
    else
        select_workspace
        # export TF_WORKSPACE=${TF_VAR_workspace}
        tf_init_s3
    fi

    tf_apply
    # unset TF_WORKSPACE   

}

function destroy {
    export TF_VAR_chdir=${TF_VAR_level}_${TF_VAR_landingzone}_${TF_VAR_tf_name}
    cd ${TF_VAR_chdir}
    EXIT_CODE=$?
    while  [ -e .terraform ]
    do
        tf_destroy || EXIT_CODE=$?

        if [[ $EXIT_CODE -eq 0 ]]
        then
            destroy_all
            git add .
            git commit -a -m "${TF_VAR_level} ${TF_VAR_landingzone} Destroyed" || COMMIT_STATE=$?
            if [[ $COMMIT_STATE -eq 0 ]]
            then
                git push origin
                git pull
            fi
            break
        fi
        EXIT_CODE=0
    done

    cd ..

}

function tf_destroy {
    if [ -z ${TF_VAR_landingzone_var_file} ]
    then
        terraform destroy                                 \
            -input=false -auto-approve  
    elif 
        [ ! -z ${TF_VAR_landingzone_extra_var_file} ]
    then
        terraform destroy                                 \
            -input=false -auto-approve                    \
            -var-file=${TF_VAR_landingzone_var_file}        \
            -var-file=${TF_VAR_landingzone_extra_var_file}
    else
        terraform destroy                                 \
            -input=false -auto-approve                    \
            --var-file=${TF_VAR_landingzone_var_file}
    fi
}

function delete_workspace {

    terraform workspace select default || true
    terraform workspace delete ${TF_VAR_workspace} || true

}

function delete_backend {

    BACKEND=("backend*.tf" "lowerlevel_data_remote_state*.tf" "env_backend*.sh")

    for file in ${BACKEND[@]}
    do
        [ -e "${file}" ] && rm -rf "${file}"
    done
}

function delete_tfstate {

    TFSTATE=(".terraform*" ".terraform.lock.hcl*" "terraform.tfstate.d*" "errored.tfstate*" "terraform.tfstate*" "dev.log" ".terraform.lock.hcl.icloud" ".deployed" "errored.tfstate")

    for object in ${TFSTATE[@]}
    do
        [ -e "${object}" ] && rm -rf "${object}"; echo "deleted ${object}"
    done
}

function destroy_all {

    delete_workspace || true
    delete_backend || true
    delete_tfstate || true
}

function set_lower_level {
    export TF_VAR_lowerlevel_level=${TF_VAR_level}
    export TF_VAR_lowerlevel_workspace=${TF_VAR_workspace}
    export TF_VAR_lowerlevel_landingzone=${TF_VAR_landingzone}
    export TF_VAR_lowerlevel_chdir=${TF_VAR_chdir}
    export TF_VAR_lowerlevel_backend_bucket=${TF_VAR_backend_bucket}
    export TF_VAR_lowerlevel_backend_acl=${TF_VAR_backend_acl}
    export TF_VAR_lowerlevel_backend_region=${TF_VAR_backend_region}
    export TF_VAR_lowerlevel_backend_encrypt=${TF_VAR_backend_encrypt}
    export TF_VAR_lowerlevel_backend_dynamodb_table=${TF_VAR_backend_dynamodb_table}
    export TF_VAR_lowerlevel_backend_key=${TF_VAR_backend_key}
}

function configure_lower_level {
    export TF_VAR_lowerlevel_tf_name=${TF_VAR_tf_name}
    export TF_VAR_lowerlevel_chdir=${TF_VAR_lowerlevel_level}_${TF_VAR_lowerlevel_landingzone}_${TF_VAR_lowerlevel_tf_name}
    export TF_VAR_lowerlevel_backend_key="${TF_VAR_lowerlevel_level}/${TF_VAR_lowerlevel_landingzone}/${TF_VAR_lowerlevel_tf_name}.tfstate"
}

function delete_route53_records {
    VERBOSE=true
    domain_to_delete="${TF_VAR_tf_name}.${TF_VAR_workspace}-${AWS_DEFAULT_REGION}.${DOMAIN_NAME}"
    hosted_zone_id=$(aws route53 list-hosted-zones \
                        --output text \
                        --query 'HostedZones[?Name==`'$domain_to_delete'.`].Id'
                    )
    $VERBOSE &&
        echo hosted_zone_id=${hosted_zone_id:-Unable to find: $domain_to_delete}

    if [ ! -z $hosted_zone_id ]
    then
        aws route53 list-resource-record-sets \
        --hosted-zone-id $hosted_zone_id |
        jq -c '.ResourceRecordSets[]' |
        while read -r resourcerecordset; do
            read -r name type <<<$(jq -r '.Name,.Type' <<<"$resourcerecordset")
            if [ $type == "NS" -o $type == "SOA" ]; then
            $VERBOSE && echo "SKIPPING: $type $name"
            else
            change_id=$(aws route53 change-resource-record-sets \
                --hosted-zone-id $hosted_zone_id \
                --change-batch '{"Changes":[{"Action":"DELETE","ResourceRecordSet":
                    '"$resourcerecordset"'
                }]}' \
                --output text \
                --query 'ChangeInfo.Id')
            $VERBOSE && echo "DELETING: $type $name $change_id"
            fi
        done
    fi
}