#!/bin/bash

# Author: Julian Fischer <julian.fischer@anynines>

#### Settings

DEBUG=0

# cf service name
CLUSTER_NAME="kube-rind"

CLUSTER_HOST="api-4fca26e8-2c54-4ad0-9136-542d0789b5c2.de.k9s.a9s.eu"

# Clustername within the kube.conf file
KUBECONF_CLUSTER_NAME="kubernetes"

# Username within the kube.conf file
KUBECONF_USERNAME="a9s43440f4a3c09b08fd"

TEST_NAMESPACE="k8s-training-test"

EXIT_IF_NAMESPACE_EXISTS=0

KUBECTL_PROXY_PORT="8080"

KUBECTL_PROXY_OPTS="--accept-hosts=\".*\""

#### Internal variables

RED=`tput setaf 1`
GREEN=`tput setaf 2`
YELLOW=`tput setaf 3`
BLUE=`tput setaf 4`
MAGENTA=`tput setaf 5`
CYAN=`tput setaf 6`
RESET=`tput sgr0`

# Used as a return value for functions
RETURN_VALUE=""
RETURN_VALUE_FILE="return_value.json"

#### Functions

function heading() {
    local title=$1
    printf "\n$title\n"
    printf "========================================\n\n"
}

function execute_command() {
    local command=$1

    printf "Executing ${CYAN}$command${RESET}...\n"

    RET=$(eval $command)    

    if [ $? != 0 ]
        
    then
        printf "\n${RED}Execution of $command failed!${RESET}\n\n"
    else
        printf "Execution of $command was successful!\n"
    fi
    
    # This is more readable than assinging the return value somehwere in the function's code
    RETURN_VALUE=$RET 
}

function a9s_select_cluster() {
    printf "Selecting the $CLUSTER_NAME cluster...\n"
    a9s set-cluster -c $CLUSTER_NAME
    source /Users/jfischer/Dropbox/workspace/a9s-platform/.a9s/kubeconf-switch.sh
    printf "Cluster $CLUSTER_NAME selected\n"
}

function create_namespace() {

    ns=`kubectl get namespace $TEST_NAMESPACE --no-headers --output=go-template={{.metadata.name}} 2>/dev/null`
    if [ -n "${ns}" ]; then
        echo "${YELLOW}Namespace $TEST_NAMESPACE already exists.${RESET}"
        echo "You can delete the namespace with the following command:"
        printf "\n\nkubectl delete namespace $TEST_NAMESPACE\n\n"

        if [ $EXIT_IF_NAMESPACE_EXISTS -eq 1 ]
        then
            echo "Exitting..."
            exit 1        
        else
            echo "${RED}Deleting the namespace $TEST_NAMESPACE.${RESET}"
            execute_command "kubectl delete namespace $TEST_NAMESPACE"
            echo "Deletion completed."
        fi
    fi    
    echo "Creating namespace $TEST_NAMESPACE..."
    execute_command "kubectl create namespace $TEST_NAMESPACE"
}

# Ensure that the given command exists.
function verify_that_command_exists() {
    CMD_PATH=$(which $1)

    if [ $? != 0 ]        
    then
        printf "\n${RED}It appears the command $1 does not exist. Please install it!${RESET}\n"
    else
         if [ $DEBUG -eq 1 ] ; then echo "Found command $1 at $CMD_PATH." ; fi
    fi
}

function set_namespace_context() {
    echo "Setting the namespace context..."
    execute_command "kubectl config set-context $TEST_NAMESPACE --namespace $TEST_NAMESPACE --cluster=$KUBECONF_CLUSTER_NAME --user $KUBECONF_USERNAME"
    execute_command "kubectl config use-context $TEST_NAMESPACE"
    echo "Namespace context is set."
}

function create_pod() {
    local pod_name=$1
    local pod_args=$2

    local status_cmd="kubectl get pod $pod_name --no-headers --output=custom-columns=:.status.phase"
    
    echo "Let's create a Pod: $pod_name..."
    execute_command "kubectl run $pod_name $pod_args"

    printf "Waiting for the Pod: $pod_name to be created"
    while true
    do
        STATUS=$($status_cmd)
        if [ $? -eq 0 ]
        then
            if [ $STATUS == "Pending" ]
            then 
                printf "."
            else 
                break 
            fi
        else
            echo "${RED} The Pod failed to create while being Pending: $STATUS. Return value was: $?.${RESET}"    
        fi
        sleep 1
    done
    
    printf "\n"
    
    STATUS=$($status_cmd)

    if [ $? -eq 0 -a $STATUS == "Succeeded" ]
    then
        echo "${GREEN}The Pod has been successfully created.${RESET}"
    else
        echo "${RED} The Pod failed to create after being Pending: $STATUS. Return value was: $?.${RESET}"
    fi

    echo "Done creating Pod: $pod_name."
}

function delete_pod() {
    local pod_name=$1

    echo "Deleting Pod $pod_name..."
    execute_command "kubectl delete pod $pod_name"
    echo "Done deleting Pod $pod_name."
}

function get_pod_logs() {
    local pod_name=$1

    echo "Getting Logs of Pod $pod_name..."
    
    execute_command "kubectl logs busybox"
    LOGS=$RETURN_VALUE

    if [[ $LOGS == "\"Hello World\"" ]]
    then
        printf "${GREEN}Logs of Pod: $pod_name have been successfully retrieved: $LOGS\n${RESET}"
    else
        printf "${RED}Logs of Pod: $pod_name did not contain the expected \"Hello World\" but instead: $LOGS\n"
    fi

    echo "Done getting Logs of Pod $pod_name."
}

function print_return_value() {
    printf "\n${CYAN}$RETURN_VALUE${RESET}\n\n"
}

function describe_object() {
    local object_type=$1
    local object_name=$2
    echo "Describing $object_type: $pod_name..."
    execute_command "kubectl describe $object_type $object_name"

    print_return_value

    echo "Done describing $object_type: $object_name."
}

function describe_pod() {
    local pod_name=$1
    describe_object "Pod" $pod_name
}

function kubectl_file_action() {
    local verb=$1
    local filepath=$2
    echo "Trying to kubectl $verb -f ${filepath}..."
    execute_command "kubectl $verb -f ${filepath}"
    printf "\nReturn value was:\n\n${CYAN}${RETURN_VALUE}${RESET}\n\n"
    echo "Done with kubectl $verb -f ${filepath}."
}


function create_replica_set() {
    echo "Creating a ReplicaSet..."    
    kubectl_file_action "apply" "./yaml/20-rs-hello-world.yaml"
    echo "Done creating the ReplicaSet."
}

function describe_replicat_set() {
    local replica_set_name=$1
    describe_object "ReplicaSet" $replica_set_name
}

function delete_replica_set() {
    echo "Deleting a ReplicaSet..."
    kubectl_file_action "delete" "./yaml/20-rs-hello-world.yaml"
    echo "Done deleting the ReplicaSet."
}

function create_service() {
    echo "Creating a Service ..."
    kubectl_file_action "apply" "./yaml/30-service-hello-world.yaml"
    echo "Done creating a Service."
}

function delete_service() {
    echo "Deleting the Service..."
    kubectl_file_action "delete" "./yaml/30-service-hello-world.yaml"
    echo "Done deleting the Service"
}

function start_kubectl_proxy() {
    echo "Starting kubectl proxy..."

    pgrep -f "kubectl proxy" 1> /dev/null

    if [ $? != 0 ] ; then
        echo "kubectl proxy is not running, starting it in the background..."
        printf "${CYAN}kubectl proxy --port=$KUBECTL_PROXY_PORT $KUBECTL_PROXY_OPTS &${RESET}\n"
        
        # Note: $(...) doesn't work here. Produces: kubectl proxy --port=8080 --accept-hosts=".*" &: command not found
        eval "kubectl proxy --port=$KUBECTL_PROXY_PORT $KUBECTL_PROXY_OPTS &"                
    else
        echo "${YELLOW}kubectl proxy is already running.${RESET}"
    fi    
    sleep 3
    echo "Done starting kubectl proxy."
}

function stop_kubectl_proxy() {
    echo "Stopping kubectl proxy..."
    PID=$(pgrep -f "kubectl proxy")
    execute_command "kill -HUP $PID"
    echo "Done: kubectl proxy stopped."
}

function curl_proxy() {    
    local url=$1
    printf "Curling kubectl proxy with url: $url...\n${CYAN}"
    
    printf "\tcurl -sS -k -H \"Host: $CLUSTER_HOST\" localhost:${KUBECTL_PROXY_PORT}${url} > $RETURN_VALUE_FILE\n"    

    # Again $(...) and hence execute_command doesn't work.
    eval "curl -sS -k -H \"Host: $CLUSTER_HOST\" localhost:${KUBECTL_PROXY_PORT}${url} > $RETURN_VALUE_FILE"
    printf "\n${RESET}Done curling kubectl proxy with url: $url.\n"
}

function curl_proxy_kubernetes_api() {
    echo "Curling the Kubernetes API via kubectl proxy..."
    curl_proxy "/api"
    print_return_value
    echo "Done curling the Kubernetes API via kubectl proxy"
}

function process_failed_curl_proxy_response() {
    local command="jq '.[\"code\"]' $RETURN_VALUE_FILE"    

    RET=$(eval $command)    

    if [ $? != 0 ]
        
    then
        printf "\n${RED}Execution of $command failed!${RESET}\n\n"        
    else
        printf "Execution of $command was successful. Return value was: $RET!\n"

        if [ $RET -eq 404 ]
        then
            echo "${RED}The service: $service could not be found.${RESET}"
        else
            echo "${RED}The response code was ${RETURN_VALUE}.${RESET}"
        fi
    fi
    RETURN_VALUE=$RET
}

# If the service does not exist, curl will still succeed. 
# The return_file will then contain json with a description of the error.
# If the service does exist, curl will return the response of the app referenced by the 
# service. > No JSON to parse.
# 
function process_curl_proxy_service_response() {    
    local expected_string="Stupid"
    local command="grep $expected_string $RETURN_VALUE_FILE"

    RET=$($command)

    if [ $? != 0 ]        
    then
        printf "\n${RED}The service has not been successful! Didn't find the expected String: \"$expected_string\" in the response.${RESET}\n\n"
        process_failed_curl_proxy_response
    else
        printf "${GREEN}The service has been queries successfully. Curl response was: $RET!${RESET}\n"        
    fi
    RETURN_VALUE=$RET    
}

function curl_proxy_service() {
    
    #TODO Make configurable
    local service="smpl-go-web-s"
    echo "Curling the recently created service using kubectl proxy..."
    curl_proxy "/api/v1/namespaces/$TEST_NAMESPACE/services/http:$service:8080/proxy/"    

    process_curl_proxy_service_response    

    echo "Done curling the recently created service using kubectl proxy."
}

function remove_return_value_file() {
    if test -f $RETURN_VALUE_FILE; then    
        execute_command "rm $RETURN_VALUE_FILE"
    fi
}

function create_ingress() {
    echo "Creating an Ingress..."
    kubectl_file_action "apply" "./yaml/40-ingress-hello-world-a9s.yaml"
    echo "Done creating an Ingress."
}

#### Business Logic

heading "Verifying Prerequisites"

# For colored output
verify_that_command_exists "tput"
verify_that_command_exists "kubectl"
verify_that_command_exists "jq"

heading "Selecting the Cluster"

    # For switching clusters
    # verify_that_command_exists "a9s"
    # a9s_select_cluster
    
    execute_command "kubectl cluster-info"

heading "Creating the Namespace"
    create_namespace
    set_namespace_context

# heading "Creating a simple Pod"
#     create_pod "busybox" "--image=busybox --restart=Never -- echo \"Hello World\""
#     get_pod_logs
#     describe_pod "busybox"
#     delete_pod "busybox"

heading "Creating a ReplicaSet"
    create_replica_set
    describe_replicat_set "smpl-go-web-rs"

    create_service

    start_kubectl_proxy

    curl_proxy_kubernetes_api
    curl_proxy_service

    stop_kubectl_proxy

    create_ingress

    # delete_replica_set
    # delete_service

    # delete_namespace
    #remove_return_value_file