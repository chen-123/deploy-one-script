#!/usr/bin/env bash
#################################################################################
# @author: chen-123
# @date:   2018-09-21
# @function:
#    1、部署基于LNMP的dev环境，本机及远程多服务部署模式
#    2、下线dev环境
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

if [ "$RUN_VERSION" == "" ];then
    RUN_VERSION=v1.0
fi

rm -rf $RUN-$RUN_VERSION.tar.gz

public::common::prepare_package "$RUN" "$RUN_VERSION"

#public::common::log "PKG_FILE_SERVER: $PKG_FILE_SERVER"

public::deploy-dev::deploy()
{
    if [ -z $HOSTS ];then
        public::common::log "--hosts must be provided in deploy-dev::deploy ! eg. --hosts 192.168.0.1,192.168.0.2"
        exit 1
    fi

    export NODES=${HOSTS//,/$'\n'}

    for host in $NODES;
    do
	public::common::file "run-${RUN_VERSION}.tar.gz"
        public::common::file "docker-${DOCKER_VERSION}.tar.gz"
        public::common::file "docker-compose-${DOCKER_COMPOSE_VERSION}.tar.gz"
	public::common::file "ansible_playbook.tar.gz"
    done

    for host in $NODES;
    do
        ssh -e none root@$host "export PKG_FILE_SERVER=$PKG_FILE_SERVER;\
            bash $PKG/$RUN/$RUN_VERSION/docker.sh \
                --role install-docker \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION"
    done

    for host in $NODES;
    do
        ssh -e none root@$host "export PKG_FILE_SERVER=$PKG_FILE_SERVER;\
            bash $PKG/$RUN/$RUN_VERSION/docker.sh \
                --role install-docker-compose \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION"
    done

    for host in $NODES;
    do
        ssh -e none root@$host "docker version > /dev/null 2>&1 && echo '${host} docker install ok!' || echo '${host} docker install fail!'"
	ssh -e none root@$host "docker-compose version > /dev/null 2>&1 && echo '${host} docker-compose install ok!' || echo '${host} docker-compose install fail!'"
    done
}

public::deploy-dev::lnmp()
{
    export NODES=${HOSTS//,/$'\n'}

    for host in $NODES;
    do
    	ssh -e none root@$host "export PKG_FILE_SERVER=$PKG_FILE_SERVER;\
            bash $PKG/$RUN/$RUN_VERSION/docker.sh \
                --role install-docker \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION"
    done

    #public::docker::install
    #public::docker-compose::install
    #pubilic::docker-compose::up
}

public::deploy-dev::destory()
{
    if [ -z $HOSTS ];then
        public::common::log "--hosts must be provided in master_deploy ! eg. --hosts 192.168.0.1,192.168.0.2"
        exit 1
    fi

    export NODES=${HOSTS//,/$'\n'}

    for host in $NODES;
    do
	ssh -e none root@$host "export PKG_FILE_SERVER=$PKG_FILE_SERVER;\
            bash $PKG/$RUN/$RUN_VERSION/docker.sh \
                --role purge-docker-compose \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION "
    done

    for host in $NODES;
    do
        ssh -e none root@$host "export PKG_FILE_SERVER=$PKG_FILE_SERVER;\
            bash $PKG/$RUN/$RUN_VERSION/docker.sh \
                --role purge-docker \
                --docker-version $DOCKER_VERSION \
                --kube-version $KUBE_VERSION "
    done
}

public::deploy-dev::clean_cache()
{
    export NODES=${HOSTS//,/$'\n'}

    i=0 ;
    files="run-${RUN_VERSION}.tar.gz docker-${DOCKER_VERSION}.tar.gz docker-compose-yaml.tar.gz"
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

     #[ -f /etc/ansible/hosts ] && grep 'k8s-nodes' /etc/ansible/hosts || public::common::ansible_playbook
     public::common::scripts
     public::common::files

     case $ROLE in

    "deploy-lnmp-dev" )
	public::deploy-dev::deploy
        ;;
     "install-lnmp-dev" )
        public::deploy-dev::lnmp
        ;;
     "purge-lnmp-dev" )
	public::docker-compose::purge
	public::docker::purge
        ;;
     "destroy-lnmp-dev" )
        public::deploy-dev::destory
        ;;
     "clean-cache" )
        public::deploy-dev::clean_cache
        ;;
     *)
        echo "$help"
        ;;
     esac
}

help="
Usage:
    "$0"
        --role deploy  [deploy-lnmp-dev | deploy-java-dev | destroy-lnmp-dev | clean-cache]
        --container-cidr 172.16.0.0
        --hosts 192.168.0.1,192.168.0.2,192.168.0.3
        --docker-version 17.06.ce
        --etcd-version v3.3.5
        --endpoint 192.168.0.1:6443
        --load-images false
"

main "$@"
