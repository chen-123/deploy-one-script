# deploy_lnmp_k8s_test_prod.sh 构建test、staging、prod环境

目前，脚本在centos7.4、centos7.5下测试通过，脚本默认安装docker-17.06.2.ce,etcd-v3.3.5,kubernetes-1.10.8,cni-plugins-amd64-v0.7.1 。

本脚本安装所有资源打包上传到【百度网盘】（链接: https://pan.baidu.com/s/1SOxF6cTr7sRt6Chr8_vcLQ 提取码: cbvf），资源可以自己根据需求更换。

说明：

* deploy_lnmp_k8s_test_prod.sh的功能说明 （基于Cenots 7+）

   1、k8s集群部署

        * 支持etcd集群部署，包括etcd-v3.3.5的bin文件安装、配置、上线、下线等，以及yum方式安装。

	* 支持k8s集群部署，包括kubernetes-1.10.8的bin文件安装、配置、上线、下线等，以及yum方式安装。

	* k8s集群以addons的方式，默认部署组件包括：kube-apiserver、kube-controller-manager、kube-scheduler、kube-proxy、calico、coredns、heapster、nginx-ingress、jenkins。

	* 支持自定义不同版本etcd、kubelet、kubectl、kubernetes-cni等组件，安装需求

	* 支持将上述组件按照脚本规范存储，本地内网安装，自动分发各部署服务器（yum 安装部分依赖包，解压大量时间），还可以直接从资源服务器http://download.phpdba.com自动下载。

   2、集群新增节点及组件升级

        * attach_node.sh 支持新增节点，kubelet、docker、etcd 安装部署

	* upgrade.sh 提供各节点组件，包括：docker、kubelet、kubectl、kubernetes-cni的升级、备份部署

   3、集群使用说明

	* 为简化流程及保障测试真实性，test、staging 环境直接合并处理，统一在线上集群namespace为test-staging下,生产环境namespace为prod。集群层面对主机进行lables，区分测试环境主机与生产环境主机，降低主机故障对生产业务的影响

	* test-staging 与prod的区别主要在于使用的镜像不同、数据库配置不同，其它环境基本一致

	* test-staging 确认无误之后，触发jenkins的image-auto-build的job，制作生产镜像。或者打回并提交测试报告，开发完成bug修改，重新进入test-staging流程。
	
	* 进入prod流程之后，触发jenkins的ingress-mode的job，通过发布机制上线运营。

        * jenkins 各流程阶段主要工作，可以参考CI_CD/Jenkinsfiles下Jenkinsfle的pipeline脚本，job的config文件在CI_CD/Jenkins-jobs-config目录下。 


## LNMP线上测试和生产环境部署 - deploy_lnmp_k8s_test_prod.sh

一、基本思路

1、通过deploy_lnmp_k8s_test_prod.sh提高统一部署入口，主要包括etcd集群、docker、kubulet、kubectl等安装、配置、部署、下线

2、通过common.sh进行环境变量统一维护，系统优化，预安装软件包，公共函数定义等，通过source方式引用

3、通过kubernetes.sh提供本地化docker、kubelet、kubectl等安装、配置、卸载操作，k8s的yaml组件部署

4、相关代码统一存放在当前目录下pkg/run/v1.0(版本号)下，然后将该目录打包run-v1.0.tar.gz (tar cvf run-v1.0.tar.gz pkg/run/v1.0)

5、通过deploy_lnmp_k8s_test_prod.sh上传run-v1.0.tar.gz到目标服务器，执行相关脚本

6、docker、k8s等安装资源包，提高两种方式同步到目标服务器，一种是从资源服务器下载，另一种是通过rsync同步当前目录下相关资源到目标服务器

二、运行脚本 （第三步，可选）

* 第一步：etcd 集群操作

	1、部署etcd集群

	bash deploy_lnmp_k8s_test_prod.sh --role deploy-etcd --etcd-hosts 192.168.0.148,192.168.0.149,192.168.0.150

	2、etcd集群下架

	bash deploy_lnmp_k8s_test_prod.sh --role destroy-etcd --etcd-hosts 192.168.0.148,192.168.0.149,192.168.0.150

* 第二步：k8s 集群操作

	1、k8s master 节点部署
	
	bash deploy_lnmp_k8s_test_prod.sh --role deploy-k8s-nodes --hosts 192.168.0.148,192.168.0.149,192.168.0.150 --etcd-endpoints https://192.168.0.148:2379,https://192.168.0.149:2379,https://192.168.0.150:2379 --kube-apiserver-lb https://192.168.0.148:6443

	2、k8s 节点下线

	bash deploy_lnmp_k8s_test_prod.sh --role destroy-k8s-nodes --hosts 192.168.0.148,192.168.0.149,192.168.0.150 --etcd-endpoints https://192.168.0.148:2379,https://192.168.0.149:2379,https://192.168.0.150:2379 --kube-apiserver-lb https://192.168.0.148:6443

	3、节点资源清理

	bash deploy_lnmp_k8s_test_prod.sh --role clean-cache --hosts 192.168.0.148,192.168.0.149,192.168.0.150 --etcd-endpoints https://192.168.0.148:2379,https://192.168.0.149:2379,https://192.168.0.150:2379 --kube-apiserver-lb https://192.168.0.148:6443

* 第三步：新增节点、组件升级
	1、新增节点
        bash deploy_lnmp_k8s_test_prod.sh --role deploy-k8s-nodes --hosts 192.168.0.151 --etcd-endpoints https://192.168.0.148:2379,https://192.168.0.149:2379,https://192.168.0.150:2379 --kube-apiserver-lb https://192.168.0.148:6443
       或者
	bash attach_node.sh --role deploy-k8s-nodes --hosts 192.168.0.151 --etcd-endpoints https://192.168.0.148:2379,https://192.168.0.149:2379,https://192.168.0.150:2379 --kube-apiserver-lb https://192.168.0.148:6443

	2、更新组件

	bash upgrade.sh --role upgrade-k8s-nodes --hosts 192.168.0.151 --etcd-endpoints https://192.168.0.148:2379,https://192.168.0.149:2379,https://192.168.0.150:2379 --kube-apiserver-lb https://192.168.0.148:6443
