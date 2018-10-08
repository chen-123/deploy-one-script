# deploy-one-script 构建dev、test、prod环境

经常遇到开发环境构建需求、生产环境构建需求、持续基础发布需求，所以通过deploy-one-script构建默认基于Centos7.4 + Docker-17.06.2.ce + Docker-compose-1.22.0 + kubernetes-1.10.8 + etcd-v3.3.5 + jenkins-v2.113 的LNMP的dev、test、prod环境，该脚本采用bash编写。

本脚本安装所有资源打包上传到【百度网盘】（链接: https://pan.baidu.com/s/1SOxF6cTr7sRt6Chr8_vcLQ 提取码: cbvf），资源可以自己根据需求更换。

说明：
  
	* deploy_lnmp_docker_dev.sh 部署LNMP的dev环境，详细请查看DEV.md,LNMP部署情况请查看LNMP.md

	* deploy_lnmp_k8s_test_prod.sh 部署test、staging、prod环境，详细请查看TEST-STAGING-PROD.md 

