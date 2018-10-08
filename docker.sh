#!/usr/bin/env bash
#################################################################################
# @author: chen-123
# @date:   2018-09-21
# @function:
#    1、部署LNMP的dev环境

set -x -e

source $(cd `dirname ${BASH_SOURCE}`; pwd)/common.sh

public::docker-compose::install()
{
    set +e
    docker-compose version > /dev/null 2>&1
    i=$?
    set -e
    v=$(docker-compose version|grep 'docker-compose version'|awk '{gsub(/,/, "");print $3}')
    if [ $i -eq 0 ]; then
        if [[ "$DOCKER_COMPOSE_VERSION" == "$v" ]];then
            public::common::log "docker-compose has been installed , return. $DOCKER_COMPOSE_VERSION"
            #return
        fi
    fi

    public::common::prepare_package "docker-compose" $DOCKER_COMPOSE_VERSION
    if [ "$OS" == "CentOS" ];then
	if [ $(whereis docker-compose) ];then
		docker_compose_path=$(whereis docker-compose|awk '{print $2}')
		[ -f $docker_compose_path ] && rm -rf $docker_compose_path
	fi

	# yum -y install epel-release
	# yum -y install python-pip	
	# pip install docker-compose
	local pkg=pkg/docker-compose/$DOCKER_COMPOSE_VERSION/
        if [ -f ${pkg}docker-compose ];then
		mv ${pkg}docker-compose /usr/local/bin/docker-compose
		[ -x /usr/local/bin/docker-compose ] || chmod a+x /usr/local/bin/docker-compose
	else
		curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-`uname -s`-`uname -m` -o /usr/local/bin/docker-compose
		# curl -L https://raw.githubusercontent.com/docker/compose/1.22.0/contrib/completion/bash/docker-compose -o /etc/bash_completion.d/docker-compose
		[ -x /usr/local/bin/docker-compose ] || chmod a+x /usr/local/bin/docker-compose
	fi
    elif [ "$OS" == "Ubuntu" ];then
	echo "next version ...."
    fi

    pubilic::docker-compose::up
}

pubilic::docker-compose::up()
{
    public::common::prepare_package "docker-compose" "yaml"
    local docker_compose_yaml=pkg/docker-compose/yaml/docker-compose.yml
    [ -x /usr/local/bin/docker-compose ] && /usr/local/bin/docker-compose -f ${docker_compose_yaml} up -d && echo "LNMP dev evn deploy ok!"
}

public::docker::install()
{
    set +e
    docker version > /dev/null 2>&1
    i=$?
    set -e
    v=$(docker version|grep Version|awk '{gsub(/-/, ".");print $2}'|uniq)
    if [ $i -eq 0 ]; then
        if [[ "$DOCKER_VERSION" == "$v" ]];then
            public::common::log "docker has been installed , return. $DOCKER_VERSION"
	    #break
            return
        fi
    fi
    
    public::common::prepare_package "docker" $DOCKER_VERSION
    if [ "$OS" == "CentOS" ];then
        if [ "$(rpm -qa docker-engine-selinux|wc -l)" == "1" ];then
            yum erase -y docker-engine-selinux
        fi
        if [ "$(rpm -qa docker-engine|wc -l)" == "1" ];then
            yum erase -y docker-engine
        fi
        if [ "$(rpm -qa docker-ce|wc -l)" == "1" ];then
            yum erase -y docker-ce
        fi
        if [ "$(rpm -qa container-selinux|wc -l)" == "1" ];then
            yum erase -y container-selinux
        fi

        if [ "$(rpm -qa docker-ee|wc -l)" == "1" ];then
            yum erase -y docker-ee
        fi

        local pkg=pkg/docker/$DOCKER_VERSION/rpm/
        yum localinstall -y `ls $pkg |xargs -I '{}' echo -n "$pkg{} "`
     elif [ "$OS" == "Ubuntu" ];then
        if [ "$need_reinstall" == "true" ];then
            if [ "$(echo $v|grep ee|wc -l)" == "1" ];then
                apt purge -y docker-ee docker-ee-selinux
            elif [ "$(echo $v|grep ce|wc -l)" == "1" ];then
                apt purge -y docker-ce docker-ce-selinux container-selinux
            else
                apt purge -y docker-engine
            fi
        fi
        dir=pkg/docker/$DOCKER_VERSION/debain
        dpkg -i `ls $dir | xargs -I '{}' echo -n "$dir/{} "`
    else
        public::common::log "install docker with [unsupported OS version] error!"
        exit 1
    fi
    public::docker::config
}

public::docker::config()
{
    iptables -P FORWARD ACCEPT
    sed -i "s#ExecStart=/usr/bin/dockerd#ExecStart=/usr/bin/dockerd -s overlay --selinux-enabled=false \
        --registry-mirror=https://3d13mnz1.mirror.aliyuncs.com --log-driver=json-file \
        --log-opt max-size=100m --log-opt max-file=10#g" /lib/systemd/system/docker.service

    sed -i "/ExecStart=/a\ExecStartPost=/usr/sbin/iptables -P FORWARD ACCEPT" /lib/systemd/system/docker.service

    systemctl daemon-reload ; systemctl enable  docker.service; systemctl restart docker.service
}

public::docker::purge()
{
    set +e
    docker ps -aq|xargs -I '{}' docker stop {}
    docker ps -aq|xargs -I '{}' docker rm {}
    systemctl stop  docker.service
    rm -rf /etc/docker && rm -rf /lib/systemd/system/docker.service
    if [ "$OS" == "CentOS" ];then
 	if [ "$(rpm -qa docker-engine-selinux|wc -l)" == "1" ];then
            yum erase -y docker-engine-selinux
        fi

        if [ "$(rpm -qa docker-engine|wc -l)" == "1" ];then
            yum erase -y docker-engine
        fi

        if [ "$(rpm -qa docker-ce|wc -l)" == "1" ];then
            yum erase -y docker-ce
        fi

        if [ "$(rpm -qa container-selinux|wc -l)" == "1" ];then
            yum erase -y container-selinux
        fi

        if [ "$(rpm -qa docker-ee|wc -l)" == "1" ];then
            yum erase -y docker-ee
        fi

    elif [ "$OS" == "Ubuntu" ];then
	if [ "$(echo $v|grep ee|wc -l)" == "1" ];then
        	apt purge -y docker-ee docker-ee-selinux
        elif [ "$(echo $v|grep ce|wc -l)" == "1" ];then
                apt purge -y docker-ce docker-ce-selinux container-selinux
        else
                apt purge -y docker-engine
        fi
    fi
    #rm -rf /var/lib/cni
    #ip link del docker0
    echo 'docker purge ok'
    set -e
}

public::docker-compose::purge()
{
    [ -x /usr/local/bin/docker-compose ] && [ -f pkg/docker-compose/yaml/docker-compose.yml ] && /usr/local/bin/docker-compose -f pkg/docker-compose/yaml/docker-compose.yml stop
    if [ "$OS" == "CentOS" ];then
	docker_compose_path=$(whereis docker-compose|awk '{print $2}')
        if [ "$docker_compose_path" != "" ];then
		#$docker_compose_path stop
                [ -f $docker_compose_path ] && rm -rf $docker_compose_path
        fi
	echo 'docker-compose purge ok'
    elif [ "$OS" == "Ubuntu" ];then
        echo "next version ...."
    fi
}

public::docker::load_images()
{
    local app=images
    local ver=v1.0
    agility::common::prepare_package $app $ver
    for img in `ls pkg/$app/$ver/common/`;do
        # 判断镜像是否存在，不存在才会去load
        ret=$(docker images | awk 'NR!=1{print $1"_"$2".tar"}'| grep $KUBE_REPO_PREFIX/$img | wc -l)
        if [ $ret -lt 1 ];then
            docker load < pkg/$app/$ver/common/$img
        fi
    done

    docker tag registry.cn-hangzhou.aliyuncs.com/acs/pause-amd64:3.0 \
        gcr.io/google_containers/pause-amd64:3.0 >/dev/null
}

main()
{
    public::common::parse_args "$@"
    public::common::common_env

    case $ROLE in

    "source")
        public::common::log "source scripts"
        ;;
    "install-docker" )
        public::docker::install
        ;;
    "install-docker-compose" )
        public::docker-compose::install
        ;;
    "docker-compose-up" )
        public::docker-compose::up
        ;;
    "purge-docker" )
        public::docker::purge
        ;;
    "purge-docker-compose" )
        public::docker-compose::purge
        ;;
     *)
        echo "usage: $0 --role install-docker | purge-docker | docker-compose-up  | install-docker-compose | purge-docker-compose "
        echo "       $0 --role  install-docker to setup docker service "
        echo "       $0 --role  purge-docker  to purge docker service "
	echo "       $0 --role  install-docker-compose to setup docker-compose service "
        echo "       $0 --role  purge-docker-compose  to purge docker-compose service "
        echo "       unkown command $0 $@"
        ;;
    esac
}

main "$@"
