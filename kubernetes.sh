#!/usr/bin/env bash
#################################################################################
# @author: chen-123
# @date:   2018-10-07
# @function:
#    1、部署k8s集群

set -x -e

#source $(cd `dirname ${BASH_SOURCE}`; pwd)/common.sh
source $(cd `dirname ${BASH_SOURCE}`; pwd)/docker.sh --role source

public::k8s::install_yum()
{
    cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
    yum install -y epel-release
    #yum install -y yum-utils device-mapper-persistent-data lvm2 net-tools conntrack-tools wget vim  ntpdate libseccomp libtool-ltdl telnet rsync bind-utils
    #yum install -y kubelet-1.10.8 kubeadm-1.10.8 kubectl-1.10.8
    yum remove -y kubelet-1.10.8 kubeadm-1.10.8 kubectl-1.10.8
    mkdir -p /root/.kube /etc/kubernetes/pki/etcd
}

public::k8s::install_package()
{
    public::docker::install

    public::common::prepare_package "kubernetes-flies" $KUBE_VERSION

    if [ "$OS" == "CentOS" ];then
	# files install
	dir=pkg/kubernetes-flies/$KUBE_VERSION/files
	dir2=pkg/kubernetes/$KUBE_VERSION/files
	#set +e
    	K8S_DIR=/opt/k8s-$KUBE_VERSION
    	mkdir -p $K8S_DIR /etc/kubernetes/audit /var/lib/kubelet /root/.kube /opt/cni/bin
	[ -f ${dir}/kubectl ] && cp ${dir}/kubectl $K8S_DIR && chmod a+x ${K8S_DIR}/kubectl && ln -sf ${K8S_DIR}/kubectl /usr/local/bin/kubectl
	[ -f ${dir}/kubelet ] && cp ${dir}/kubelet $K8S_DIR && chmod a+x ${K8S_DIR}/kubelet && ln -sf ${K8S_DIR}/kubelet /usr/local/bin/kubelet
	[ -f ${dir2}/kubectl ] && cp ${dir2}/kubectl $K8S_DIR && chmod a+x ${K8S_DIR}/kubectl && ln -sf ${K8S_DIR}/kubectl /usr/local/bin/kubectl
        [ -f ${dir2}/kubelet ] && cp ${dir2}/kubelet $K8S_DIR && chmod a+x ${K8S_DIR}/kubelet && ln -sf ${K8S_DIR}/kubelet /usr/local/bin/kubelet
	[ -d ${dir}/cni_bin ] && cp ${dir}/cni_bin/* /opt/cni/bin && chmod a+x /opt/cni/bin/*
        [ -d ${dir2}/cni_bin ] && cp ${dir2}/cni_bin/* /opt/cni/bin && chmod a+x /opt/cni/bin/* 
	[ -f pkg/kubernetes/$KUBE_VERSION/yaml/audit/policy.yml ] && cp pkg/kubernetes/$KUBE_VERSION/yaml/audit/policy.yml /etc/kubernetes/audit/policy.yml
    	[ -f pkg/kubernetes/$KUBE_VERSION/yaml/kubelet/config.yml ] && cp pkg/kubernetes/$KUBE_VERSION/yaml/kubelet/config.yml /var/lib/kubelet && sed -i 's#CLUSTER_DNS#'${CLUSTER_DNS}'#g' /var/lib/kubelet/config.yml
	[ -s /etc/kubernetes/audit/policy.yml ] || \
cat << EOT > /etc/kubernetes/audit/policy.yml
apiVersion: audit.k8s.io/v1beta1
kind: Policy
rules:
- level: Metadata
EOT
	
	#set -e
        # rpm install 
        #dir=pkg/kubernetes/$KUBE_VERSION/rpm
        #yum localinstall -y `ls $dir | xargs -I '{}' echo -n "$dir/{} "`
    elif [ "$OS" == "Ubuntu" ];then
        dir=pkg/kubernetes/$KUBE_VERSION/debain
        dpkg -i `ls $dir | xargs -I '{}' echo -n "$dir/{} "`
    fi

    #public::k8s::kubelet_service
    #public::k8s::manifests
    #public::k8s::set_kubeconfig

    #systemctl daemon-reload && systemctl enable kubelet.service && systemctl start kubelet.service
}

public::k8s::kubelet_service()
{
    public::common::nodeid
    mkdir -p /etc/systemd/system/kubelet.service.d/
    cat << EOT > /tmp/kubelet.service.tmp
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=http://kubernetes.io/docs/

[Service]
ExecStart=/usr/local/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOT
    mv /tmp/kubelet.service.tmp /etc/systemd/system/kubelet.service
    cat << EOT > /tmp/kubelet.server.d.tmp
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/admin.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --pod-cidr=${CONTAINER_CIDR}"
Environment="KUBELET_DNS_ARGS=--cluster-dns=${CLUSTER_DNS} --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS=--authorization-mode=Webhook --client-ca-file=/etc/kubernetes/pki/ca.pem"
Environment="KUBELET_CADVISOR_ARGS=--cadvisor-port=0"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_CERTIFICATE_ARGS=--rotate-certificates=true --cert-dir=/var/lib/kubelet/pki"
Environment="KUBELET_EXTRA_ARGS=--node-labels=node-role.kubernetes.io/master='' --v=2 --fail-swap-on=false --kube-api-qps=500 --max-pods=200  --pod-infra-container-image=chenphper/pause-amd64:3.1 --hostname-override=${NODE_IP} "
ExecStart=
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_SYSTEM_PODS_ARGS \$KUBELET_NETWORK_ARGS \$KUBELET_DNS_ARGS \$KUBELET_AUTHZ_ARGS \$KUBELET_CADVISOR_ARGS \$KUBELET_CGROUP_ARGS \$KUBELET_CERTIFICATE_ARGS \$KUBELET_EXTRA_ARGS
EOT

cat << EOT > /tmp/kubelet.server.d.8080
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--kubeconfig=/etc/kubernetes/admin.conf"
Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true"
Environment="KUBELET_NETWORK_ARGS=--network-plugin=cni --cni-conf-dir=/etc/cni/net.d --cni-bin-dir=/opt/cni/bin --pod-cidr=${CONTAINER_CIDR}"
Environment="KUBELET_DNS_ARGS=--cluster-dns=${CLUSTER_DNS} --cluster-domain=cluster.local"
Environment="KUBELET_AUTHZ_ARGS="
Environment="KUBELET_CADVISOR_ARGS=--cadvisor-port=0"
Environment="KUBELET_CGROUP_ARGS=--cgroup-driver=cgroupfs"
Environment="KUBELET_CERTIFICATE_ARGS="
Environment="KUBELET_EXTRA_ARGS=--v=2 --fail-swap-on=false --kube-api-qps=500 --max-pods=200  --pod-infra-container-image=chenphper/pause-amd64:3.1 --hostname-override=${NODE_IP} "
ExecStart=
ExecStart=/usr/local/bin/kubelet \$KUBELET_KUBECONFIG_ARGS \$KUBELET_SYSTEM_PODS_ARGS \$KUBELET_NETWORK_ARGS \$KUBELET_DNS_ARGS \$KUBELET_AUTHZ_ARGS \$KUBELET_CADVISOR_ARGS \$KUBELET_CGROUP_ARGS \$KUBELET_CERTIFICATE_ARGS \$KUBELET_EXTRA_ARGS
EOT

    #mv /tmp/kubelet.server.d.8080 /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    mv /tmp/kubelet.server.d.tmp /etc/systemd/system/kubelet.service.d/10-kubeadm.conf
    #systemctl daemon-reload && systemctl enable kubelet && systemctl start kubelet 
}

public::k8s::set_kubeconfig()
{
    mkdir -p /etc/kubernetes/pki/etcd/
    \cp -rf /var/lib/etcd/cert/{ca.pem,etcd-client.pem,etcd-client-key.pem} /etc/kubernetes/pki/etcd/ && echo "etcd cert copy success" || echo "etcd cert copy fail"

    cat << EOT > /tmp/kubeconfig.tmp
apiVersion: v1
clusters:
- cluster:
    server: ${KUBE_APISERVER_LB}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: admin
  name: kubernetes
current-context: kubernetes
kind: Config
preferences: {}
users: []
EOT
    #mv /tmp/kubeconfig.tmp /etc/kubernetes/admin.conf
    [ -d /root/.kube ] || mkdir /root/.kube
    #\cp /etc/kubernetes/admin.conf /root/.kube/config
    #\cp /etc/kubernetes/admin.conf /etc/kubernetes/controller-manager.conf
    #\cp /etc/kubernetes/admin.conf /etc/kubernetes/scheduler.conf
}

public::k8s::cluster_addon(){
    dir=pkg/kubernetes/$KUBE_VERSION/yaml/addons
    sed -i "s#10.244.0.0/16#${CONTAINER_CIDR}#g" $dir/calico/calico.yaml
    sed -i "s#https://192.168.0.107:6443#${KUBE_APISERVER_LB}#g" $dir/kube-proxy/kube-proxy.yaml

    kubectl apply \
		-f $dir/kube-proxy/kube-proxy.yaml \
		-f $dir/calico/ \
		-f $dir/coredns/ \
		-f $dir/nginx-ingress/ \
       		-f $dir/rbac/  \
		-f $dir/heapster.yaml \
		-f $dir/dashboard.yaml \
		-f $dir/dashboard-ing.yaml \
		-f $dir/jenkins/

   kubectl apply -f $dir/basic-auth.yaml -n kube-system
   kubectl apply -f $dir/basic-auth.yaml -n ci
   sleep 5
}

public::k8s::manifests()
{
    public::common::prepare_package "kubernetes" $KUBE_VERSION
    local pkg_manifests=pkg/kubernetes/${KUBE_VERSION}/yaml/manifests/
    local dir=/etc/kubernetes/manifests
    mkdir -p $dir
    while [ ! -f $dir/kube-apiserver.yaml ];
    do
	cp -f ${pkg_manifests}/* ${dir}/
        public::common::log "wait for manifests to be ready." ; sleep 3
    done

    public::common::log "ETCD_SERVERS: ${ETCD_SERVERS}"
    public::common::log "ETCD_HOSTS: ${ETCD_HOSTS}"

    for file in `ls $dir`
    do
	sed -i 's#NODE_IP#'${NODE_IP}'#g' $dir/$file
	sed -i 's#SVC_CLUSTER_CIDR#'${SVC_CIDR}'#g' $dir/$file
	sed -i 's#CLUSTER_CIDR#'${CONTAINER_CIDR}'#g' $dir/$file
	sed -i 's#ETCD_SERVERS#'${ETCD_SERVERS}'#g' $dir/$file
    done
}

public::k8s::genssl()
{
    type cfssl > /dev/null 2>&1 || { echo >&2 "I require cfssl, but it's not installed.  Aborting.";exit 100; }
    [ -d pki ] && rm -rf pki
    mkdir -p pki/ 
    dir=pki
    echo '{"CN":"kubernetes","key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"k8s","OU":"System"}]}' | cfssl gencert -initca - | cfssljson -bare $dir/ca -
    echo '{"CN":"kubernetes","key":{"algo":"rsa","size":2048}}' | cfssl gencert -initca - | cfssljson -bare $dir/front-proxy-ca -
    echo '{"signing":{"default":{"expiry":"438000h"},"profiles":{"kubernetes":{"usages":["signing","key encipherment","server auth","client auth"],"expiry":"438000h"}}}}' > $dir/ca-config.json

    export ADDRESS=${HOSTS},k8s.chen-123.com,k8s.local,k8s,kubernetes,10.254.0.1,127.0.0.1,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local
    export NAME=kubernetes
    echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"k8s","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${ADDRESS}" - | cfssljson -bare $dir/$NAME
    export NAME=kube-apiserver
    echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"Kubernetes","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${ADDRESS}" - | cfssljson -bare $dir/$NAME

    export ADDRESS=
    export NAME=kube-proxy
    echo '{"CN":"system:kube-proxy","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"system:kube-proxy","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${ADDRESS}" - | cfssljson -bare $dir/$NAME

    export NAME=kube-scheduler
    echo '{"CN":"system:kube-scheduler","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"system:kube-scheduler","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${ADDRESS}" - | cfssljson -bare $dir/$NAME

    export NAME=kube-controller-manager
    echo '{"CN":"system:kube-controller-manager","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"system:kube-controller-manager","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${ADDRESS}" - | cfssljson -bare $dir/$NAME

    export NAME=admin
    echo '{"CN":"'$NAME'","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"system:masters","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${ADDRESS}" - | cfssljson -bare $dir/$NAME

    export NAME=kubelet
    for NODE in ${HOSTS//,/$'\n'};
    do
    	echo '{"CN":"system:node:'$NODE'","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"system:nodes","OU":"System"}]}'  | cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes -hostname="${NODE}" - | cfssljson -bare $dir/${NAME}-${NODE} 
    done

    echo '{"CN":"front-proxy-client","hosts":[""],"key":{"algo":"rsa","size":2048},"names":[{"C":"CN","ST":"NanJing","L":"NanJing","O":"system:masters","OU":"System"}]}' | \
    cfssl gencert -config=$dir/ca-config.json -ca=$dir/ca.pem -ca-key=$dir/ca-key.pem -profile=kubernetes - | cfssljson -bare $dir/front-proxy-client

    openssl genrsa -out $dir/sa.key 2048 
    openssl rsa -in $dir/sa.key -pubout -out $dir/sa.pub
    # TLS Bootstrapping 使用的 Token
    BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ') 
    echo "${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,\"system:kubelet-bootstrap\"" > ${dir}/token.csv
    
    rm -rf pki/*.json pki/*.csr 
    [ -f pki.tar ] && rm -f pki.tar || echo "pki.tar not exist.pls create it"
    tar -cvf pki.tar pki
    for host in ${HOSTS//,/$'\n'};
    do
    	scp pki.tar root@$host:/root/pki.tar
    	ssh -e none root@$host 'mkdir -p /etc/kubernetes/; tar xf pki.tar -C /etc/kubernetes/'
    done
}

public::k8s::set_controller_manager_kubeconfig()
{
    # 设置集群参数
    kubectl config set-cluster kubernetes \
        --certificate-authority=pki/ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER_LB} \
        --kubeconfig=kube-controller-manager.conf
    # 设置客户端认证参数
    kubectl config set-credentials system:kube-controller-manager \
        --client-certificate=pki/kube-controller-manager.pem \
        --embed-certs=true \
        --client-key=pki/kube-controller-manager-key.pem \
        --kubeconfig=kube-controller-manager.conf
    # 设置上下文参数
    kubectl config set-context system:kube-controller-manager@kubernetes \
        --cluster=kubernetes \
        --user=system:kube-controller-manager \
        --kubeconfig=kube-controller-manager.conf
    # 设置默认上下文
    kubectl config use-context system:kube-controller-manager@kubernetes \
       	--kubeconfig=kube-controller-manager.conf


    for h in ${HOSTS//,/$'\n'};
    do
        rsync -avL kube-controller-manager.conf root@${h}:/etc/kubernetes/
    done
    [ -f kube-controller-manager.conf ] && rm -f kube-controller-manager.conf || echo "kube-controller-manager.conf is not exist"
}

public::k8s::set_scheduler_kubeconfig()
{
    # 设置集群参数
    kubectl config set-cluster kubernetes \
        --certificate-authority=pki/ca.pem \
        --embed-certs=true \
        --server=${KUBE_APISERVER_LB} \
        --kubeconfig=kube-scheduler.conf
    # 设置客户端认证参数
    kubectl config set-credentials system:kube-scheduler \
        --client-certificate=pki/kube-scheduler.pem \
        --embed-certs=true \
        --client-key=pki/kube-scheduler-key.pem \
        --kubeconfig=kube-scheduler.conf
    # 设置上下文参数
    kubectl config set-context system:kube-scheduler@kubernetes \
        --cluster=kubernetes \
        --user=system:kube-scheduler \
        --kubeconfig=kube-scheduler.conf
    # 设置默认上下文
    kubectl config use-context system:kube-scheduler@kubernetes \
        --kubeconfig=kube-scheduler.conf


    for h in ${HOSTS//,/$'\n'};
    do
        rsync -avL kube-scheduler.conf root@${h}:/etc/kubernetes/
    done
    [ -f kube-scheduler.conf ] && rm -f kube-scheduler.conf || echo "kube-scheduler.conf is not exist"
}

public::k8s::set_kubeconfig_admin_conf()
{
    # 设置集群参数
    kubectl config set-cluster kubernetes \
    	--certificate-authority=pki/ca.pem \
    	--embed-certs=true \
    	--server=${KUBE_APISERVER_LB} \
       	--kubeconfig=admin.conf
    # 设置客户端认证参数
    kubectl config set-credentials admin \
    	--client-certificate=pki/admin.pem \
    	--embed-certs=true \
    	--client-key=pki/admin-key.pem \
	--kubeconfig=admin.conf
    # 设置上下文参数
    kubectl config set-context admin@kubernetes \
    	--cluster=kubernetes \
    	--user=admin \
	--kubeconfig=admin.conf

    # 设置默认上下文
    kubectl config use-context admin@kubernetes \
  	--kubeconfig=admin.conf

    
    for h in ${HOSTS//,/$'\n'};
    do
	rsync -avL admin.conf root@${h}:/etc/kubernetes/
      	rsync -avL admin.conf root@${h}:/root/.kube/config
    done
    [ -f admin.conf ] && rm -f admin.conf || echo "admin.conf is not exist"
}

public::k8s::set_kubeconfig_bootstrap_conf()
{
    if [ -f pki/token.csv ]
    then
      	BOOTSTRAP_TOKEN=`cat pki/token.csv |awk -F ',' '{print $1}'`
    fi

    #kubectl create clusterrolebinding kubelet-bootstrap --clusterrole=system:node-bootstrapper --user=kubelet-bootstrap

    kubectl config set-cluster kubernetes \
    	--certificate-authority=pki/ca.pem \
    	--embed-certs=true \
    	--server=${KUBE_APISERVER_LB} \
    	--kubeconfig=bootstrap.kubeconfig

    kubectl config set-credentials kubelet-bootstrap \
    	--token=${BOOTSTRAP_TOKEN} \
    	--kubeconfig=bootstrap.kubeconfig

    kubectl config set-context default \
    	--cluster=kubernetes \
    	--user=kubelet-bootstrap \
    	--kubeconfig=bootstrap.kubeconfig

    kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

    for h in ${HOSTS//,/$'\n'};
    do
	rsync -avL bootstrap.kubeconfig root@${h}:/etc/kubernetes/
    done
    [ -f bootstrap.kubeconfig ] && rm -f bootstrap.kubeconfig || echo "bootstrap.kubeconfig is not exist"
}

public::k8s::set_kubeconfig_proxy_conf()
{
    kubectl config set-cluster kubernetes \
    	--certificate-authority=pki/ca.pem \
    	--embed-certs=true \
    	--server=${KUBE_APISERVER_LB} \
    	--kubeconfig=kube-proxy.kubeconfig

    kubectl config set-credentials kube-proxy \
    	--client-certificate=pki/kube-proxy.pem \
    	--client-key=pki/kube-proxy-key.pem \
    	--embed-certs=true \
    	--kubeconfig=kube-proxy.kubeconfig

    kubectl config set-context default \
    	--cluster=kubernetes \
    	--user=kube-proxy \
    	--kubeconfig=kube-proxy.kubeconfig

    kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

    for h in ${HOSTS//,/$'\n'};
    do
      	rsync -avL kube-proxy.kubeconfig root@${h}:/etc/kubernetes/
    done
    [ -f kube-proxy.kubeconfig ] && rm -f kube-proxy.kubeconfig || echo "kube-proxy.kubeconfig is not exist"
}

public::k8s::wait_apiserver()
{
    ret=1
    while [[ $ret != 0 ]]; do
        sleep 2
	#netstat -nlpt|grep kube-apiser >/dev/null 2>&1  && echo "ok" || echo "fail"
        curl -k https://127.0.0.1:6443 >/dev/null 2>&1
        ret=$?
    done
}

public::k8s::node_down(){
    set +e
    kubelet_num=$(ps aux|grep kubelet|grep -v grep |wc -l)
    [ "${kubelet_num}" != "0" ] && systemctl stop kubelet.service
    #kubeadm reset
    docker ps -aq|xargs -I '{}' docker stop {}
    docker ps -aq|xargs -I '{}' docker rm {}
    df |grep /var/lib/kubelet|awk '{ print $6 }'|xargs -I '{}' umount {}
    rm -rf /var/lib/kubelet && rm -rf /etc/kubernetes/
    if [ "$OS" == "CentOS" ];then
	# remove kubenetes by rm file
	K8S_DIR=/opt/k8s-$KUBE_VERSION
	rm -f /usr/local/bin/kubectl ${K8S_DIR}/kubectl
	rm -f /usr/local/bin/kubelet ${K8S_DIR}/kubelet
	rm -f /etc/systemd/system/kubelet.service
        rm -rf $K8S_DIR /etc/kubernetes /root/.kube /etc/systemd/system/kubelet.service.d /var/lib/kubelet
	# remove kubenetes by yum
        # yum remove -y kubectl  kubelet kubernetes-cni
    elif [ "$OS" == "Ubuntu" ];then
        apt purge -y kubectl kubeadm kubelet kubernetes-cni
    fi
    rm -rf /var/lib/cni
    public::docker::purge
    ip link del tunl0 || echo 'net tunl0 not exist'
    set -e
}

public::k8s::init_master_config(){
    public::common::nodeid
    # 使能master，可以被调度到
    # kubectl taint nodes --all dedicated-

    # 添加kubernetes-dashboard 证书，添加控制台CA
    #if [ ! -f /etc/kubernetes/pki/client-ca.crt ];then
    #    touch /etc/kubernetes/pki/client-ca.crt
    #fi
    #cat /etc/kubernetes/pki/client-ca.crt >> /etc/kubernetes/pki/apiserver.crt
    #cp -rf /etc/kubernetes/pki/apiserver.crt /etc/kubernetes/pki/dashboard/dashboard.crt
    #cp -rf /etc/kubernetes/pki/apiserver.key /etc/kubernetes/pki/dashboard/dashboard.key
    #cp -rf /etc/kubernetes/pki/ca.crt /etc/kubernetes/pki/dashboard/dashboard-ca.crt
    #cat /etc/kubernetes/pki/client-ca.crt >> /etc/kubernetes/pki/dashboard/dashboard-ca.crt

    #export KUBECONFIG=/etc/kubernetes/admin.conf

    # show pods
    #kubectl get po --all-namespaces 


    # 调整kubelet.conf的apiserver 地址
    sed -i 's#'${KUBE_APISERVER_LB}'#https://'${NODE_IP}':6443#g' /etc/kubernetes/admin.conf
    sed -i 's#'${KUBE_APISERVER_LB}'#https://'${NODE_IP}':6443#g' /root/.kube/config
    sed -i 's#'${KUBE_APISERVER_LB}'#https://'${NODE_IP}':6443#g' /etc/kubernetes/bootstrap.kubeconfig
    sed -i 's#'${KUBE_APISERVER_LB}'#https://'${NODE_IP}':6443#g' /etc/kubernetes/kube-controller-manager.conf
    sed -i 's#'${KUBE_APISERVER_LB}'#https://'${NODE_IP}':6443#g' /etc/kubernetes/kube-scheduler.conf
    #sed "/server: https:/d" /etc/kubernetes/admin.conf | \
    #    sed "/- cluster:/a \    server: https://`echo $EXTRA_SANS|awk -F, '{print $1}'`:6443" >/etc/kubernetes/kube.conf


    systemctl restart kubelet; systemctl restart docker

    #echo "export KUBECONFIG=/etc/kubernetes/admin.conf" >> ~/.bashrc

    echo "K8S master nodes install finished!"
}

public::main::post_init()
{
    # replace kube-proxy apiserver endpoint to $APISERVER_LB
    kubectl -n=kube-system get configmap kube-proxy -o yaml > kube-proxy.yaml
    #sed -i "s#server: https://.*\$#server: https://$APISERVER_LB:6443#g" kube-proxy.yaml
    kubectl -n=kube-system delete configmap kube-proxy
    kubectl create -f kube-proxy.yaml
    # recreate kube-proxy pod to enable new configmap
    kubectl -n=kube-system delete po `kubectl -n=kube-system get pods -o name | grep kube-proxy`
}

public::k8s::node_up()
{
    #public::k8s::install_yum
    public::k8s::install_package
    public::k8s::kubelet_service
    public::k8s::set_kubeconfig

    [ -f pki.tar ] && echo "pki scp:{$host}" 
    ret=$?  
    if [ $ret -ne 0 ];then
        public::common::log 'pki.tar not exists'
        [ -d /etc/kubernetes/pki ] || exit 1
	ssh -e none root@$host 'mkdir -p /etc/kubernetes/pki/'
	for file in $(ls /etc/kubernetes/pki/*.pem) ;
	do
		scp $file root@$host:/etc/kubernetes/pki/
	done
    else
    	for host in ${HOSTS//,/$'\n'};
    	do
              scp pki.tar root@$host:/root/pki.tar
       	      ssh -e none root@$host 'mkdir -p /etc/kubernetes/; tar xf pki.tar -C /etc/kubernetes/'
    	done
    fi

    #if [ "$LOAD_IMAGE" == "true" ];then
    #    public::docker::load_images node
    #fi

    systemctl daemon-reload && systemctl enable kubelet.service && systemctl start kubelet.service
}

public::k8s::waitnodeready()
{
    for ((i=0;i<40;i++));do
        cnt=$(kubectl get no|grep NotReady|wc -l)
        if [ $cnt -eq 0 ];then
            break;
        fi
        sleep 3
    done
}

public::k8s::master_deploy()
{
    etcdctl --ca-file /var/lib/etcd/cert/ca.pem --cert-file /var/lib/etcd/cert/etcd-client.pem  --key-file /var/lib/etcd/cert/etcd-client-key.pem  --endpoints ${ETCD_SERVERS} cluster-health

    ret=$?
    if [ $ret -ne 0 ];then
        public::common::log 'etcd cluster not running'
        exit 1
    fi

    public::k8s::install_package
    public::k8s::kubelet_service
    public::k8s::manifests
    public::k8s::set_kubeconfig

    systemctl daemon-reload && systemctl enable kubelet.service && systemctl start kubelet.service
}

main()
{
    public::common::parse_args "$@"
    public::common::common_env
    #public::common::node_env

    case $ROLE in

    "source")
        public::common::log "source scripts"
        ;;
    "deploy-k8s" )
	public::k8s::install_package
        ;;
    "deploy-masters" )
        public::k8s::master_deploy
        ;;
    "init_master_config" )
        public::k8s::init_master_config
        ;;
    "node-up" )
        public::k8s::node_up
        ;;
    "destroy-nodes" )
        public::k8s::destroy_cluster
        ;;
    "node-down" )
        public::k8s::node_down
        ;;
    *)
        echo "usage: $0 --role deploy [deploy-k8s | deploy-masters | init_master_config | node-up | destroy-node | node-down] to setup master node kubenetnes componet "
        echo "       --docker-version   to install docker version "
        echo "       --kube-version   to install kubernetes version "
        echo "       --etcd-endpoints   to set etcds cluster endpoints "
	echo "       --kube-apiserver-lb   to set kube-apiversion-lb endpoint "
	echo "       --cluster-dns   to set cluster-dns IP"
	echo "       --svc-cidr   to set service cidr"
	echo "       --container-cidr   to set container & pods cidr"
        echo "       unkown command $0 $@"
        ;;
    esac
}


main "$@"
