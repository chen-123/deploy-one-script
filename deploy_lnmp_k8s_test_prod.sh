#!/usr/bin/env bash
#################################################################################
# @author: chen-123
# @date:   2018-09-21
# @function:
#    1、部署etcd集群
#    2、部署k8s集群
#    3、清除部署遗留资源
# @parameter:
#   PKG_FILE_SERVER set the package download server. default to regionize oss store.
#   PKG_FILE_SERVER=http://download.phpdba.com
#
#
# 首先从本地读取相应版本的tar包。当所需要的安装包不存在的时候
# 如果设置了参数PKG_FILE_SERVER，就从该Server上下载。

set -e -x

PKG=pkg
#source $(cd `dirname ${BASH_SOURCE}`; pwd)/common.sh
source $(cd `dirname ${BASH_SOURCE}`; pwd)/docker.sh --role source
source $(cd `dirname ${BASH_SOURCE}`; pwd)/kubernetes.sh --role source

public::common::log "PKG_FILE_SERVER: $PKG_FILE_SERVER"

if [ "$RUN_VERSION" == "" ];then
    RUN_VERSION=v1.0
fi

#rm -rf $RUN-$RUN_VERSION.tar.gz

public::common::prepare_package "$RUN" "$RUN_VERSION"

source $PKG/$RUN/$RUN_VERSION/etcd.sh --role source

public::k8s-deploy::master-nodes-deploy()
{
    public::common::master_env

    public::k8s::genssl

    export NODES=${HOSTS//,/$'\n'}

    i=0

    public::common::log "etcd-server: ${ETCD_SERVERS}"
    self=$(cd `dirname $0`; pwd)/`basename $0`
    for host in $NODES;
    do

        public::common::log "BEGAIN: join nodes:$host"
        ssh -e none root@$host "export PKG_FILE_SERVER=${PKG_FILE_SERVER};export ETCD_SERVERS=${ETCD_SERVERS};export KUBE_APISERVER_LB=${KUBE_APISERVER_LB};\
            bash $PKG/$RUN/$RUN_VERSION/kubernetes.sh \
                --role deploy-masters \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION \
                --load-images $LOAD_IMAGES \
		--etcd-endpoints $ETCD_SERVERS \
                --kube-apiserver-lb $KUBE_APISERVER_LB \
                --cluster-dns $CLUSTER_DNS \
                --svc-cidr $SVC_CIDR \
                --container-cidr $CONTAINER_CIDR \
                "
        echo "END: join node:$host finish!"
    done

    # 初始化集群kubeconfig file 
    public::k8s::set_kubeconfig_admin_conf
    public::k8s::set_kubeconfig_bootstrap_conf
    public::k8s::set_kubeconfig_proxy_conf
    public::k8s::set_controller_manager_kubeconfig
    public::k8s::set_scheduler_kubeconfig
    public::k8s::wait_apiserver && public::k8s::cluster_addon || echo "k8s componet install fail"
    #public::k8s::cluster_addon

    for host in $NODES;
    do
        public::common::log "BEGAIN: init master nodes config :$host"
        ssh -e none root@$host "export PKG_FILE_SERVER=${PKG_FILE_SERVER};export ETCD_SERVERS=${ETCD_SERVERS};export KUBE_APISERVER_LB=${KUBE_APISERVER_LB};\
            bash $PKG/$RUN/$RUN_VERSION/kubernetes.sh \
                --role init_master_config \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION \
                --load-images $LOAD_IMAGES \
                --etcd-endpoints $ETCD_SERVERS \
                --kube-apiserver-lb $KUBE_APISERVER_LB \
                --cluster-dns $CLUSTER_DNS \
                --svc-cidr $SVC_CIDR \
                --container-cidr $CONTAINER_CIDR \
                "
    done
}

public::k8s-deploy::nodes-deploy()
{
    #public::common::node_env

    export NODES=${HOSTS//,/$'\n'}

    i=0

    public::common::log "etcd-server: ${ETCD_SERVERS}"
    self=$(cd `dirname $0`; pwd)/`basename $0`
    for host in $NODES;
    do

        public::common::log "BEGAIN: join nodes:$host"
        ssh -e none root@$host "export PKG_FILE_SERVER=${PKG_FILE_SERVER};export ETCD_SERVERS=${ETCD_SERVERS};export KUBE_APISERVER_LB=${KUBE_APISERVER_LB};\
            bash $PKG/$RUN/$RUN_VERSION/kubernetes.sh \
                --role node-up \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION \
                --load-images $LOAD_IMAGES \
                --etcd-endpoints $ETCD_SERVERS \
                --kube-apiserver-lb $KUBE_APISERVER_LB \
                --cluster-dns $CLUSTER_DNS \
                --svc-cidr $SVC_CIDR \
                --container-cidr $CONTAINER_CIDR \
                "
        echo "END: join node:$host finish!"
    done

    # 初始化集群kubeconfig file 
    public::k8s::set_kubeconfig_admin_conf
    public::k8s::set_kubeconfig_bootstrap_conf
    public::k8s::set_kubeconfig_proxy_conf
}

public::deploy-k8s::destroy_cluster(){
    export MASTERS=${HOSTS//,/$'\n'}

    self=$(cd `dirname $0`; pwd)/`basename $0`
    for host in $MASTERS;
    do
        public::common::log "BEGAIN: destroy master:$host"

        ssh -e none root@$host "bash $PKG/$RUN/$RUN_VERSION/kubernetes.sh --role node-down --hosts $HOSTS "
    done
}

public::main::download_package()
{
    #package_name=$1
    #package_ver=$2
    #public::common::prepare_package "$package_name" "$package_ver"
    public::common::prepare_package "run" "${RUN_VERSION}"
    public::common::prepare_package "etcd" "${ETCD_VERSION}"
    public::common::prepare_package "docker" "${DOCKER_VERSION}"
}

public::main::clean_cache()
{
    if [ "$ETCD_HOSTS" != "" ];then
        export NODES=${ETCD_HOSTS//,/$'\n'}
    elif [ "$HOSTS" != "" ];then
        export NODES=${HOSTS//,/$'\n'}
    fi

    i=0 ;
    files="run-${RUN_VERSION}.tar.gz etcd-${ETCD_VERSION}.tar.gz docker-${DOCKER_VERSION}.tar.gz kubernetes-flies-${KUBE_VERSION}.tar.gz docker-compose-${DOCKER_COMPOSE_VERSION}.tar.gz kubernetes-${KUBE_VERSION}.tar.gz pkg"
    for host in $NODES;
    do
        public::common::log "clean cache file:$host, "
        ssh -e none root@$host "rm -rf $files"
    done
}

main()
{
     public::common::parse_args "$@"
     public::common::common_env
     #public::common::node_env

     #[ -f /etc/ansible/hosts ] && grep 'k8s-nodes' /etc/ansible/hosts || public::common::ansible_playbook
     public::common::scripts
     public::common::files

     case $ROLE in

    "source")
        public::common::log "source scripts"
        ;;
    "deploy-etcd" )
        public::etcd::deploy
        ;;
    "deploy-k8s-masters" )
        public::k8s-deploy::master-nodes-deploy
        ;;
    "deploy-k8s-nodes" )
        public::k8s-deploy::nodes-deploy
        ;;
    "destroy-etcd" )
        public::etcd::destroy
        ;;
    "destroy-k8s-nodes" )
	public::deploy-k8s::destroy_cluster
        ;;
    "clean-cache" )
        public::main::clean_cache
        ;;
    *)
        echo "$help"
        ;;
     esac
}

help="
Usage:
    "$0"
        --role deploy  [deploy-etcd | deploy-k8s-masters  | deploy-k8s-nodes | destroy-etcd | destroy-k8s-nodes | clean-cache]
        --container-cidr 172.16.0.0
        --hosts 192.168.0.1,192.168.0.2,192.168.0.3
        --etcd-hosts 192.168.0.1,192.168.0.2,192.168.0.3
        --kube-apiserver-lb https://192.168.0.10:6443
        --docker-version 17.06.ce
        --etcd-version v3.3.5
        --token  abc.abbbbbbbbb
        --etcd-endpoint https://192.168.0.1:2379,https://192.168.0.2:2379,https://192.168.0.3:2379
        --load-images false
"

main "$@"
