#!/usr/bin/env bash

#set -e -x

source $(cd `dirname ${BASH_SOURCE}`; pwd)/common.sh

public::upgrade::current_version()
{
    export curr_version=$(kubectl version|grep -F 'Server'|awk -F "GitVersion:" '{print $2}'|cut -d '"' -f 2)
    export curr_version=${curr_version:1}
}
public::common::log "OS：$OS"
public::common::log "OS_All：$OS_All"
public::common::log "OS_Arch：$OS_Arch"
public::common::log "OS_Kernel：$OS_Kernel"

public::upgrade::kubelet()
{
    public::k8s::install_package

    public::common::log "Kubelet Successful upgrade to [$KUBE_VERSION], Node. `hostname`"
}

public::upgrade::docker()
{
    public::docker::install

    systemctl daemon-reload ; systemctl enable docker ; systemctl restart docker

    public::common::log "Docker Successful upgrade to [$DOCKER_VERSION], Node. `hostname`"
}

