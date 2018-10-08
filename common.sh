#!/usr/bin/env bash

PKG=pkg

#################################
# 初始化OS环境变量 
#################################
public::common::os_env()
{
    ubu=$(cat /etc/issue|grep "Ubuntu "|wc -l)
    cet=$(cat /etc/centos-release|grep "CentOS"|wc -l)
    if [ "$ubu" == "1" ];then
        export OS="Ubuntu"
	export OS_All=$(cat /etc/issue)
        export OS_Arch=$(uname -i)
        export OS_Kernel=$(uname -r)
    elif [ "$cet" == "1" ];then
        export OS="CentOS"
	export OS_All=$(cat /etc/centos-release)
	export OS_Arch=$(uname -i)
	export OS_Kernel=$(uname -r)
    elif [ "$(uname)" == "Darwin" ];then
    	export OS="MacOS"
        export OS_All=$(uname -v)
        export OS_Arch=$(uname -m)
        export OS_Kernel=$(uname -r)
    else
       public::common::log "unkown os...   exit"
       exit 1
    fi
}

#################################
# 初始化工具脚本环境变量
#################################
public::common::common_env()
{
    public::common::os_env

    if [ -z $DOCKER_VERSION ];then
        export DOCKER_VERSION=17.06.2.ce
    fi

    if [ -z $DOCKER_COMPOSE_VERSION ];then
        export DOCKER_COMPOSE_VERSION=1.22.0
    fi 

    if [ -z $RUN ];then
        export RUN=run
    fi

    if [ -z $RUN_VERSION ];then
        export RUN_VERSION=v1.0
    fi

    if [ -z $ETCD_VERSION ];then
        export ETCD_VERSION=v3.3.5
    fi

    if [ -z $KUBE_VERSION ];then
        export KUBE_VERSION=1.10.8
    fi
 
    if [ -z $REPO_YUM ];then
        #public::common::log "REPO_YUM does not provided , set to default false"
        export REPO_YUM="false"
    fi

    if [ -z $RSYNC_TIME ];then
        #public::common::log "RSYNC_TIME does not provided , set to default false"
        export RSYNC_TIME="false"
    fi
    #public::common::log "RSYNC_TIME does not provided , set to default false ${RSYNC_TIME}"

    if [ -z $DEFAULT_INSTALL_PACKAGE ];then
        #public::common::log "DEFAULT_INSTALL_PACKAGE does not provided , set to default vim tree"
        export DEFAULT_INSTALL_PACKAGE="ansible rsync"
    fi
 
    if [ -z $OPTIMIZE ];then
	#public::common::log "OPTIMIZE does not provided , set to default false "
        export OPTIMIZE="false"
    fi
 
    if [ -z $LOAD_IMAGES ];then
        public::common::log "--load-images does not provided , set to default false"
        export LOAD_IMAGES="false"
    fi

    public::common::with_cidr
}

public::common::master_env()
{   
    if [ -z $KUBE_APISERVER_LB ];then
        public::common::log "--kube-apiserver-lb must be provided!"
        exit 1
    fi 
    if [ -z $ETCD_SERVERS ];then
        public::common::log "--etcd-endpoints must be provided! comma separated!"
        exit 1
    fi 
    if [ -z $HOSTS ];then
        public::common::log "--host must be provided! comma separated! "
        exit 1
    fi
}

public::common::node_env()
{   
    if [ -z $KUBE_APISERVER_LB ];then
        public::common::log "--kube-apiserver-lb must be provided!"
        exit 1
    fi
 
    if [ -z $ETCD_SERVERS ];then
        public::common::log "--etcd-endpoints must be provided! comma separated!"
        exit 1
    fi
 
    if [ -z $HOSTS ];then
        public::common::log "--hosts must be provided ! eg. --hosts 192.168.0.1,192.168.0.2"
        exit 1
    fi
}

public::common::nodeid()
{
    IP_ADDR=`ip addr | grep inet | grep -Ev '127|inet6|172|10.2' | awk '{print $2}' | awk -F'/' '{print $1}'`
    export NODE_IP=${IP_ADDR}
}

#################################
# 初始化默认网段
#################################
public::common::default_cidr()
{
    gw=$(ip route |grep default|cut -d ' ' -f 3)
    # startwith

    if [[ $gw = "172."* ]];then
        export SVC_CIDR="192.168.240.0/20" CONTAINER_CIDR="192.168.0.0/20" CLUSTER_DNS="192.168.240.10"
    fi

    if [[ $gw = "10."* ]] ;then
        export SVC_CIDR="172.19.0.0/20" CONTAINER_CIDR="172.16.0.0/16" CLUSTER_DNS="172.19.0.10"
    fi

    if [[ $gw = "192.168"* ]];then
        export SVC_CIDR="10.254.0.0/16" CONTAINER_CIDR="10.244.0.0/16" CLUSTER_DNS="10.254.0.10"
    fi

    echo SVC_CIDR=$SVC_CIDR, CONTAINER_CIDR=$CONTAINER_CIDR, CLUSTER_DNS=$CLUSTER_DNS
}

#################################
# 设置default cidr cluster_dns
#################################
public::common::with_cidr()
{
    if [ "$CONTAINER_CIDR" == "" -o "$CONTAINER_CIDR" == "None" ] ;
    then
        # Using default cidr.
        public::common::default_cidr
        #return
    fi
    public::common::cluster_dns "$SVC_CIDR"
}

# calculate cluster dns , append with 10.
public::common::cluster_dns()
{
    prefix=$(echo $1 |cut -d "." -f 1)
    p_len=$((${1#*/}-8))
    for i in `seq 2 3`;
    do
        if [ $p_len -ge 8 ];then
            prefix=$prefix.$(echo $1|cut -d '.' -f $i)
        else
            net=$((0xFF << (8-$p_len)))
            prefix=$prefix.$(($(echo $1|cut -d '.' -f $i) & $net))
        fi
        p_len=$(($p_len - 8))
    done
    export CLUSTER_DNS=$prefix.10
    public::common::log "using cluster dns: $CLUSTER_DNS"
}

#################################
# 设置默认时区 ，定时时间同步crontab
#################################
public::common::rsyn_time()
{
    yum -y install ntp
    rm -f /etc/localtime  && ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
    /usr/sbin/ntpdate -u cn.pool.ntp.org
    ( [ ! -f /var/spool/cron/root ] && echo "* 4 * * * /usr/sbin/ntpdate cn.pool.ntp.org > /dev/null 2>&1" >> /var/spool/cron/root ) || ( grep 'ntpdate' /var/spool/cron/root || echo "* 4 * * * /usr/sbin/ntpdate cn.pool.ntp.org > /dev/null 2>&1" >> /var/spool/cron/root)
    systemctl  restart crond.service
}

#################################
# 更换操作系统apt、yum等源站
#################################
public::common::prepare_yum()
{
    public::common::prepare_package "aliyun" repo
    if [ "$OS" == "CentOS" ];then
	yum install -y wget curl
	local pkg=pkg/aliyun/repo/
	if [ -f ${pkg}aliyun-Centos-7.repo ];then
		mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
		mv ${pkg}aliyun-Centos-7.repo /etc/yum.repos.d/CentOS-Base.repo
        else
                mv /etc/yum.repos.d/CentOS-Base.repo /etc/yum.repos.d/CentOS-Base.repo.backup
		wget -O /etc/yum.repos.d/CentOS-Base.repo http://mirrors.aliyun.com/repo/Centos-7.repo
	fi

	if [ -f ${pkg}aliyun-epel-7.repo ];then
                [ -f /etc/yum.repos.d/epel.repo ] && mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
                mv ${pkg}aliyun-epel-7.repo /etc/yum.repos.d/epel.repo
	else
		[ -f /etc/yum.repos.d/epel.repo ] && mv /etc/yum.repos.d/epel.repo /etc/yum.repos.d/epel.repo.backup
		wget -O /etc/yum.repos.d/epel.repo http://mirrors.aliyun.com/repo/epel-7.repo
		# rpm -ivh http://dl.Fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-8.noarch.rpm
        fi
	#yum重新建立缓存
	yum clean all
	yum makecache
	#yum update -y
    elif [ "$OS" == "Ubuntu" ];then
	# Ubuntu 下个版本
	apt purge -y wget curl	
    fi
}

#################################
# ansible 同步配置文件
#################################
public::common::ansible_playbook()
{
    public::common::prepare_package "ansible" playbook
    if [ "$OS" == "CentOS" ];then
	local pkg=pkg/ansible/playbook/
        if [ -f ${pkg}ansible_host.txt ];then
        	public::common::log "ansible_host exist"
		rpm -qa|grep ansible >/dev/null 2>&1 && echo "ansible has been installed" || yum install -y ansible
		[ -f /etc/ansible/hosts ] && grep 'k8s-nodes' /etc/ansible/hosts || cat ${pkg}ansible_host.txt >> /etc/ansible/hosts
		#sed -i 's/^#ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s$/ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking＝no/' /etc/ansible/ansible.cfg
		sed -i 's/^#host_key_checking = False$/host_key_checking = False/' /etc/ansible/ansible.cfg
        fi

	if [ -f ${pkg}playbook.yml ];then
		ansible-playbook ${pkg}playbook.yml
		#cd $pkg && ansible-playbook playbook.yml
	fi
    elif [ "$OS" == "Ubuntu" ];then
	# Ubuntu 下个版本
	echo "Ubuntu ..."
    fi
}

#################################
# 系统默认安装包
#################################
public::common::default_install_package()
{
    if [ "$OS" == "CentOS" ];then
	for soft in $DEFAULT_INSTALL_PACKAGE;
	do
	    rpm -qa|grep $soft >/dev/null 2>&1 && echo "$soft has been installed" || yum install -y $soft
	done
    elif [ "$OS" == "Ubuntu" ];then
        # Ubuntu 下个版本
        apt purge -y vim
    fi
}

#################################
# 判断安装包是否存在，不存在的话，从服务器下载解压
#################################
public::common::prepare_package()
{
    PKG_TYPE=$1
    PKG_VERSION=$2
    if [ ! -f ${PKG_TYPE}-${PKG_VERSION}.tar.gz ];then
        if [ -z $PKG_FILE_SERVER ] ;then
            public::common::log "local file ${PKG_TYPE}-${PKG_VERSION}.tar.gz does not exist, And PKG_FILE_SERVER is not config"
            public::common::log "installer does not known where to download installer binary package without PKG_FILE_SERVER env been set. Error: exit"
            exit 1
        fi
        public::common::log "local file ${PKG_TYPE}-${PKG_VERSION}.tar.gz does not exist, trying to download from [$PKG_FILE_SERVER]"
        curl --retry 4 $PKG_FILE_SERVER/pkg/$PKG_TYPE/${PKG_TYPE}-${PKG_VERSION}.tar.gz \
                > ${PKG_TYPE}-${PKG_VERSION}.tar.gz || (public::common::log "download failed with 4 retry,exit 1" && exit 1)
    fi
    tar -xvf ${PKG_TYPE}-${PKG_VERSION}.tar.gz || (public::common::log "untar ${PKG_VERSION}.tar.gz failed!, exit" && exit 1)
}

#################################
# 日志输出函数
#################################
public::common::log(){
    echo $(date +"[%Y%m%d %H:%M:%S]: ") $1
}

#################################
# 操作系统优化
#################################
public::common::optimize()
{
    systemctl is-enabled firewalld && systemctl disable firewalld && systemctl stop firewalld || echo "firewalld is disabled"
    #systemctl list-unit-files |grep enabled|grep firewalld && systemctl disable firewalld && systemctl stop firewalld || echo "firewalld is disabled"
    if [ "$OS" == "CentOS" ];then
	grep 'ulimit -SHn' /etc/rc.local || echo "ulimit -SHn 102400" >> /etc/rc.local
        grep '*           soft' /etc/security/limits.conf || cat >> /etc/security/limits.conf << EOF
*           soft   nofile       655350
*           hard   nofile       655350
*	    soft   nproc	655350
*	    hard   nproc	65536
*	    soft   memlock	unlimited
*	    hard   memlock	unlimited
EOF
        cat <<EOF | tee /etc/sysctl.d/k8s.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
        sysctl -p /etc/sysctl.d/k8s.conf  || echo "/etc/sysctl.d/k8s.conf sysctl fail"
        #sed -i '/net.bridge.bridge-nf-call-iptables/d' /etc/sysctl.conf
        #sed -i '/net.bridge.bridge-nf-call-ip6tables/d' /etc/sysctl.conf
        #sed -i '$a net.bridge.bridge-nf-call-iptables = 1' /etc/sysctl.conf
        #sed -i '$a net.bridge.bridge-nf-call-ip6tables = 1' /etc/sysctl.conf
        #echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
	sed -i "/fs.may_detach_mounts/ d" /etc/sysctl.conf
    	echo "fs.may_detach_mounts=1" >> /etc/sysctl.conf
        sed -i "/vm.swappiness/ d" /etc/sysctl.conf
	echo "vm.swappiness=0" >> /etc/sysctl.conf
        sed '/swap.img/d' -i /etc/fstab
	setenforce  0 || echo "setenforce  0 is ok"
	sed -i -e "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/sysconfig/selinux
	sed -i -e "s/^SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
	sed -i -e "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/sysconfig/selinux
	sed -i -e "s/^SELINUX=permissive/SELINUX=disabled/g" /etc/selinux/config
	sed -i 's/^GSSAPIAuthentication yes$/GSSAPIAuthentication no/' /etc/ssh/sshd_config
	sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
	sed -i 's/GSSAPIAuthentication yes/GSSAPIAuthentication no/' /etc/ssh/ssh_config
	sed -i '/StrictHostKeyChecking no/d' /etc/ssh/ssh_config
	sed -i '$a \ \ \ \ \ \ \ \ StrictHostKeyChecking no' /etc/ssh/ssh_config
	systemctl  restart sshd.service
	grep 'vm.overcommit_memory' /etc/sysctl.conf || cat >> /etc/sysctl.conf << EOF
vm.overcommit_memory = 1
net.ipv4.ip_forward = 1
net.ipv4.tcp_fin_timeout = 1
net.ipv4.tcp_keepalive_time = 1200
net.ipv4.tcp_mem = 94500000 915000000 927000000
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_tw_recycle = 1
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_synack_retries = 1
net.ipv4.tcp_syn_retries = 1
net.ipv4.tcp_abort_on_overflow = 0
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 262144
net.ipv4.tcp_max_orphans = 3276800
net.ipv4.tcp_max_syn_backlog = 262144
net.core.wmem_default = 8388608
net.core.rmem_default = 8388608
EOF
	/sbin/sysctl -p
	# vim 优化略
	cat << EOF
+-------------------------------------------------+
|               optimizer is done                 |
|   it's recommond to restart this server !       |
+-------------------------------------------------+
EOF
    elif [ "$OS" == "Ubuntu" ];then
        echo "Ubuntu ..."
    fi
}

#################################
# 命令行参数解析
#################################
public::common::parse_args()
{
    while [[ $# -gt 0 ]]
    do
    key="$1"

    case $key in
        --kube-version)
            export KUBE_VERSION=$2
            shift
        ;;
        --docker-version)
            export DOCKER_VERSION=$2
            shift
        ;;
        --role)
            export ROLE=$2
            shift
        ;;
        --etcd-version)
            export ETCD_VERSION=$2
            shift
            ;;
        --etcd-hosts)
            export ETCD_HOSTS=$2
            shift
            ;;
        --etcd-endpoints)
            export ETCD_SERVERS=$2
            shift
            ;;
        --hosts)
            export HOSTS=$2
            shift
            ;;
        --kube-apiserver-lb)
            export KUBE_APISERVER_LB=$2
            shift
        ;;
        --key-secret)
            export KEY_SECRET=$2
            shift
        ;;
        --endpoint)
            export ENDPOINT=$2
            shift
        ;;
        --token)
            export TOKEN=$2
            shift
        ;;
        --cluster-dns)
            export CLUSTER_DNS=$2
            shift
        ;;
        --load-images)
            export LOAD_IMAGES=$2
            shift
        ;;
        --cluster-ca)
            export CLUSTER_CA=$2
            shift
        ;;
        --cluster-cakey)
            export CLUSTER_CAKEY=$2
            shift
        ;;
        --client-ca)
            export CLIENT_CA=$2
            shift
        ;;
        --container-cidr)
            export CONTAINER_CIDR=$2
            shift
        ;;
        --svc-cidr)
            export SVC_CIDR=$2
            shift
        ;;
        --rsync-time)
	    export RSYNC_TIME="true"
	    public::common::log "RSYNC_TIME does not provided , set to default false ${RSYNC_TIME}"
	;;
        --force)
            export FORCE="--force"
        ;;
        --gpu-enabled)
            export GPU_ENABLED=1
        ;;
        *)
            public::common::log "unknow option [$key]"
        ;;
    esac
    shift
    done
}

public::common::scripts()
{
    public::common::log " ETCD_HOSTS option [$ETCD_HOSTS]"
    public::common::log " HOSTS option [$HOSTS]"
    if [ "$ETCD_HOSTS" != "" -a "$HOSTS" == "" ];then
    	export NODES=${ETCD_HOSTS//,/$'\n'}
    elif [ "$HOSTS" != "" ];then
	export NODES=${HOSTS//,/$'\n'}
    fi

    for host in $NODES;
    do
        public::common::log "copy scripts:$host"
        cat $RUN-$RUN_VERSION.tar.gz | ssh -e none root@$host "cat > $RUN-$RUN_VERSION.tar.gz; tar xf $RUN-$RUN_VERSION.tar.gz"
    done
}

public::common::files()
{
    if [ "$ETCD_HOSTS" != "" -a "$HOSTS" == "" ];then
        export NODES=${ETCD_HOSTS//,/$'\n'}
    elif [ "$HOSTS" != "" ];then
        export NODES=${HOSTS//,/$'\n'}
    fi

    files="etcd-${ETCD_VERSION}.tar.gz docker-${DOCKER_VERSION}.tar.gz kubernetes-flies-${KUBE_VERSION}.tar.gz docker-compose-${DOCKER_COMPOSE_VERSION}.tar.gz kubernetes-${KUBE_VERSION}.tar.gz"
    for host in $NODES;
    do
	for file in $files;
	do
		public::common::log "copy file:${file} to ${host}"
        	[ -f $file ] && /usr/bin/rsync -avP -e 'ssh -e none' $file root@$host:/root/ || echo "${file} 不存在。。。"
	done
    done
}

public::common::file()
{
    if [ "$ETCD_HOSTS" != "" ];then
        export NODES=${ETCD_HOSTS//,/$'\n'}
    elif [ "$HOSTS" != "" ];then
        export NODES=${HOSTS//,/$'\n'}
    fi

    file=$1
    for host in $NODES;
    do
        public::common::log "copy file:${file} to $host"
        [ -f $file ] && /usr/bin/rsync -avP -e 'ssh -e none' ${file} root@$host:/root/  || echo "${file} 不存在。。。"
    done
}

function version_gt() { test "$(echo "$@" | tr " " "\n" | sort -V | head -n 1)" != "$1"; }

function retry()
{
        local n=0;local try=$1
        local cmd="${@: 2}"
        [[ $# -le 1 ]] && {
            echo "Usage $0 <retry_number> <Command>";
        }
        set +e
        until [[ $n -ge $try ]]
        do
                $cmd && break || {
                        echo "Command Fail.."
                        ((n++))
                        echo "retry $n :: [$cmd]"
                        sleep 2;
                        }
        done
        set -e
}

# 首先从本地读取相应版本的tar包。当所需要的安装包不存在的时候
# 如果设置了参数PKG_FILE_SERVER，就从该Server上下载。
if [ "$PKG_FILE_SERVER" == "" ];then
    export PKG_FILE_SERVER=http://download.phpdba.com
fi

#public::common::common_env

if [ "$REPO_YUM" == "true" ];then
    public::common::prepare_yum
fi

public::common::log  "rsyn_time 1 $RSYNC_TIME"
if [ "$RSYNC_TIME" == "true" ];then
    public::common::log  "rsyn_time 2"
    public::common::rsyn_time
fi
public::common::log  "rsyn_time 3"

# DEFAULT_INSTALL_PACKAGE 通过参数传入，初始化
public::common::default_install_package

#if [ "$OPTIMIZE" == "true" ];then
    public::common::optimize
#fi

#public::common::ansible_playbook
