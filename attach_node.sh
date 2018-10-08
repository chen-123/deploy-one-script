#!/usr/bin/env bash

################################################
#
# KUBE_VERSION     the expected kubernetes version
# eg.  ./attach_node.sh 
#           --docker-version 17.06.2-ce \
#           --kube-apiserver-lb https://192.168.0.80:6443
#           --cluster-dns 172.19.0.0/24
################################################

source $(cd `dirname ${BASH_SOURCE}`; pwd)/deploy_lnmp_k8s_test_prod.sh --role source

set -e -x

PKG=pkg


main()
{
    public::common::parse_args "$@"
    public::common::common_env

    if [ "$DOCKER_VERSION" == "" ] ;
    then
        public::common::log "DOCKER_VERSION $DOCKER_VERSION is not set."
        exit 1
    fi


    #KUBE_VERSION=$(curl -k https://$KUBE_APISERVER_LB/version|grep gitVersion |awk '{print $2}'|cut -f2 -d \")
    #export KUBE_VERSION=${KUBE_VERSION:1}

    if [ "$KUBE_VERSION" == "" ] ;
    then
        public::common::log "KUBE_VERSION $KUBE_VERSION is failed to set."
        exit 1
    fi

    if [ "$CLUSTER_DNS" == "" ] ;
    then
        public::common::log "CLUSTER_DNS $CLUSTER_DNS is not set."
        exit 1
    fi

    public::common::nodeid
    public::k8s-deploy::nodes-deploy
}

main "$@"
