#!/usr/bin/env bash
#################################################################################
# @author: chen-123
# @date:   2018-09-21
# @function:
#    1、部署etcd集群

set -e
set -x

source $(cd `dirname ${BASH_SOURCE}`; pwd)/common.sh

publice::common::get_local_ip() {
    IP_ADDR=`ip addr | grep inet | grep -Ev '127|inet6' | awk '{print $2}' | awk -F'/' '{print $1}'`
    export NODE_IP=${IP_ADDR}
    export THIS_NAME=${IP_ADDR}-name THIS_IP=${IP_ADDR}
    export TOKEN=$(uuidgen) CLUSTER_STATE=new
    echo   $TOKEN>/tmp/etcd.token.csv
}

public::etcd::install_etcd()
{

    if [ -z $ETCD_VERSION ];then
        public::common::log "ETCD_VERSION must be provided ! --etcd-version v3.0.17 "
        exit 1
    fi

    public::common::prepare_package etcd $ETCD_VERSION

    public::common::nodeid
    public::common::log "NODE_IP:${NODE_IP} install etcd $ETCD_VERSION"
    
    set +e
    ETCD_DIR=/opt/etcd-$ETCD_VERSION
    mkdir -p $ETCD_DIR /var/lib/etcd /etc/etcd
    groupadd -r etcd
    useradd -r -g etcd -d /var/lib/etcd -s /sbin/nologin -c "etcd user" etcd
    chown -R etcd:etcd /var/lib/etcd

    #publice::common::get_local_ip
    #public::etcd::service

    if [ ! -f /tmp/etcd.service-ssl.tmp ];then
	public::common::log "Error: Pls define /tmp/etcd.service.tmp for etcd."
	exit 1
    fi
    #mv /tmp/etcd.service.tmp /lib/systemd/system/etcd.service
    mv /tmp/etcd.service-ssl.tmp /lib/systemd/system/etcd.service

    tar xzf $PKG/etcd/$ETCD_VERSION/etcd-${ETCD_VERSION}-linux-amd64.tar.gz --strip-components=1 -C $ETCD_DIR;
    \cp -rf $PKG/etcd/$ETCD_VERSION/{cfssl,cfssljson} /usr/local/bin/
    chmod +x /usr/local/bin/{cfssl,cfssljson}
    ln -sf $ETCD_DIR/etcd /usr/local/bin/etcd
    ln -sf $ETCD_DIR/etcdctl /usr/local/bin/etcdctl
    
    etcd --version
    public::common::log "etcd binary installed. Start to enable etcd"
    systemctl daemon-reload && systemctl enable etcd && systemctl start etcd
    sleep 2
    set -e
}

public::etcd::down()
{
    set +e
    [ -f /usr/lib/systemd/system/etcd.service ] && systemctl disable etcd && systemctl stop etcd
    rm -rf /var/lib/etcd /usr/lib/systemd/system/etcd.service && echo "etcd data etcd.service delete success" || echo "file:etcd.service or dir:/var/lib/etcd not exist "
    #rm -rf /usr/local/bin/{cfssl,cfssljson} && echo "cfssl cfssljson delete success" || echo "cfssl cfssljson not exist"
    set -e
}

public::etcd::service()
{
    cat << EOT > /tmp/etcd.service-ssl.tmp
[Unit]
Description=etcd service
After=network.target

[Service]
#Type=notify
WorkingDirectory=/var/lib/etcd/
User=etcd
ExecStart=/usr/local/bin/etcd --data-dir=data.etcd --name ${THIS_NAME} \
	--client-cert-auth --trusted-ca-file=/var/lib/etcd/cert/ca.pem \
	--cert-file=/var/lib/etcd/cert/k8s-etcd-server.pem --key-file=/var/lib/etcd/cert/k8s-etcd-server-key.pem \
	--peer-client-cert-auth --peer-trusted-ca-file=/var/lib/etcd/cert/peer-ca.pem \
	--peer-cert-file=/var/lib/etcd/cert/${THIS_NAME}.pem --peer-key-file=/var/lib/etcd/cert/${THIS_NAME}-key.pem \
	--initial-advertise-peer-urls=https://${THIS_IP}:2380 --listen-peer-urls=https://${THIS_IP}:2380 \
	--advertise-client-urls=https://${THIS_IP}:2379 --listen-client-urls=https://${THIS_IP}:2379,http://127.0.0.1:2379,http://127.0.0.1:4001 \
	--initial-cluster=${CLUSTER} \
	--initial-cluster-state=${CLUSTER_STATE} --initial-cluster-token=${TOKEN}
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOT
cat << EOT > /tmp/etcd.service.tmp
[Unit]
Description=etcd service
After=network.target

[Service]
#Type=notify
WorkingDirectory=/var/lib/etcd/
User=etcd
ExecStart=/usr/local/bin/etcd --data-dir=data.etcd --name=${THIS_NAME} \
        --initial-advertise-peer-urls=http://${THIS_IP}:2380 --listen-peer-urls=http://${THIS_IP}:2380 \
        --advertise-client-urls=http://${THIS_IP}:2379 --listen-client-urls=http://${THIS_IP}:2379,http://127.0.0.1:2379,http://127.0.0.1:4001 \
        --initial-cluster=${CLUSTER} \
        --initial-cluster-state=${CLUSTER_STATE} --initial-cluster-token=${TOKEN}
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOT
}

public::etcd::genssl()
{
    [ -d cert ] && rm -rf cert
    mkdir -p cert/
    dir=cert
    echo '{"CN":"CA","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare $dir/ca -
    echo '{"signing":{"default":{"expiry":"438000h","usages":["signing","key encipherment","server auth","client auth"]}}}' > $dir/ca-config.json

    export ADDRESS=${ETCD_HOSTS},etcd.chen-123.com,etcd.local,etcd
    export NAME=k8s-etcd-server
    echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $dir/$NAME
    export ADDRESS=
    export NAME=etcd-client
    echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -hostname="$ADDRESS" - | cfssljson -bare $dir/$NAME

    # gen peer-ca
    echo '{"CN":"Peer-CA","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare $dir/peer-ca -
    echo '{"signing":{"default":{"expiry":"438000h","usages":["signing","key encipherment","server auth","client auth"]}}}' > $dir/peer-ca-config.json
    
    i=0
    for host in $ETCD_HOST;
    do
	((i=i+1))
        export MEMBER=${host}-name-$i
	echo '{"CN":"'${MEMBER}'","hosts":[""],"key":{"algo":"rsa","size":2048}}' | cfssl gencert -ca=$dir/peer-ca.pem -ca-key=$dir/peer-ca-key.pem -config=$dir/peer-ca-config.json -profile=peer -hostname="$host,${MEMBER}.local,${MEMBER}" - | cfssljson -bare $dir/${MEMBER}
	done;
}

public::etcd::deploy()
{
    public::common::scripts

    if [ -z $ETCD_VERSION ];then
        public::common::log "ETCD_VERSION must be provided ! --etcd-version v3.0.17 "
        exit 1
    fi

    if [ -z $ETCD_HOSTS ];then
        public::common::log "Target Host must be provided ! --etcd-hosts a,b,c "
        exit 1
    fi

    public::common::prepare_package etcd $ETCD_VERSION

    cp -rf $PKG/etcd/$ETCD_VERSION/{cfssl,cfssljson} /usr/local/bin/ && chmod +x /usr/local/bin/{cfssl,cfssljson}

    public::common::log "ETCD_HOSTS: ${ETCD_HOSTS} "
    export ETCD_HOST=${ETCD_HOSTS//,/$'\n'}

    export TOKEN=$(uuidgen) CLUSTER_STATE=new
    echo   $TOKEN>/tmp/etcd.token.csv

    i=0
    self=$(cd `dirname $0`; pwd)/`basename $0`

    public::common::log "ETCD_HOST: ${ETCD_HOST} "
    # For machine 1
    for h in $ETCD_HOST;
    do
        ((i=i+1))
        CLUSTER="${CLUSTER}${h}-name-$i=https://${h}:2380,"
        ssh -e none root@$h "bash $PKG/$RUN/$RUN_VERSION/etcd.sh --role down --etcd-hosts $ETCD_HOSTS --etcd-version $ETCD_VERSION"
    done

    public::etcd::genssl 
    tar cvf etcd-cert.tar cert

    CLUSTER=${CLUSTER%,*}
    i=0
    for host in $ETCD_HOST;
    do
        public::common::log "BEGAIN: $self, $host, $THIS_NAME, $THIS_IP"
        ((i=i+1))
        export THIS_NAME=${host}-name-$i THIS_IP=${host}

        public::etcd::service

        scp /tmp/etcd.service-ssl.tmp root@$host:/tmp/etcd.service-ssl.tmp
	scp etcd-cert.tar root@$host:/root/etcd-cert.tar
	#ssh -e none root@$host 'mkdir -p /var/lib/etcd'
        ssh -e none root@$host 'mkdir -p /var/lib/etcd ; tar xf etcd-cert.tar -C /var/lib/etcd/'
        ssh -e none root@$host "export PKG_FILE_SERVER=$PKG_FILE_SERVER; bash $PKG/$RUN/$RUN_VERSION/etcd.sh --role up --etcd-hosts $ETCD_HOSTS --etcd-version $ETCD_VERSION"
    done
}

public::etcd::destroy(){

    if [ -z $ETCD_HOSTS ];then
        public::common::log "Target Host must be provided ! --etcd-hosts a,b,c "
        exit 1
    fi
    export ETCD_HOST=${ETCD_HOSTS//,/$'\n'}

    self=$(cd `dirname $0`; pwd)/`basename $0`

    # For machine 1
    for host in $ETCD_HOST;
    do
        ssh -e none root@$host "bash $PKG/$RUN/$RUN_VERSION/etcd.sh --role down --etcd-hosts $ETCD_HOSTS --etcd-version $ETCD_VERSION"
    done
}

main()
{
    public::common::parse_args "$@"

    case $ROLE in

    "source")
        public::common::log "source scripts"
        ;;
    "deploy" )
        public::etcd::deploy
        ;;
    "destroy" )
        public::etcd::destroy
        ;;
    "up" )
        public::etcd::install_etcd
        ;;
    "down" )
        public::etcd::down
        ;;
    *)
        echo "usage: $0 --role deploy --hosts 192.168.0.1,192.168.0.2,192.168.0.3 "
        echo "       $0 --role destroy --hosts 192.168.0.1,192.168.0.2,192.168.0.3"

        ;;
    esac
}
main "$@"
