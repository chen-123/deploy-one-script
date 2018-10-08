# deploy_lnmp_docker_dev.sh 构建dev环境

经常遇到开发环境构建需求，所以通过脚本构建基于Centos7.4 + Docker + Docker-compose的开发环境，该脚本采用bash编写。

目前，脚本在centos7.4、centos7.5下测试通过，脚本默认安装docker-17.06.2.ce,docker-compose-1.22.0 。

本脚本安装所有资源打包上传到【百度网盘】（链接: https://pan.baidu.com/s/1SOxF6cTr7sRt6Chr8_vcLQ 提取码: cbvf），资源可以自己根据需求更换。

说明：

* deploy_lnmp_docker_dev.sh的功能说明 （基于Cenots 7+）

   1、本机部署

	* 支持本机一键部署LNMP的dev环境,本地修改代码可以马上查看效果，开发完成之后提交版本控制系统,进行CI/CD流程。

	* 当前目录下pkg/docker-compose/yaml/www对应的项目名称目录，是php项目代码,修改代码直接看效果

	* 当前目录下pkg/docker-compose/yaml/conf，是nginx、php、mysql配置，修改配置项之后，需要重启相关容器或者容器内服务

	* 当前目录下pkg/docker-compose/yaml/php，是不同版本php镜像的dockerfile文件，定制php模块、依赖资源等

   2、远程部署 

	* 支持批量多服务器一键部署LNMP的dev环境，方便团队协同开发工作。

	* 默认目录下/root/pkg/docker-compose/yaml/www对应的项目名称目录，是php项目代码,修改代码直接看效果

        * 默认目录下/root/pkg/docker-compose/yaml/conf，是nginx、php、mysql配置，修改配置项之后，需要重启相关容器或者容器内服务

        * 默认目录/root/pkg/docker-compose/yaml/php，是不同版本php镜像的dockerfile文件，定制php模块、依赖资源等

	* 基于gitlab等版本控制系统的分支机制，同时部署gitlab-runner用于代码更新保障。

	* 登陆开发机器或者docker容器，直接修改

	* 本机通过ansible或者lsyncd同步php代码

## LNMP的dev环境部署 - deploy_lnmp_docker_dev.sh

### 一、基本思路

1、通过deploy_lnmp_docker_dev.sh提供统一部署入口，主要包括docker、docker-compose等安装、配置、部署、下线

2、通过common.sh进行环境变量统一维护，系统优化，预安装软件包，公共函数定义等，通过source方式引用

3、通过docker.sh提供本地化docker、docker-compose安装、配置、卸载操作

4、相关代码统一存放在当前目录下pkg/run/v1.0(版本号)下，然后将该目录打包run-v1.0.tar.gz (tar cvf run-v1.0.tar.gz pkg/run/v1.0)

5、通过deploy_lnmp_docker_dev.sh上传run-v1.0.tar.gz到目标服务器，执行相关脚本

### 二、运行脚本部署

1、远程部署方式(脚本自动将run-v1.0.tar.gz，上传到目标服务器/root下，然后ssh远程执行脚本)

	a、批量部署192.168.1.113,192.168.1.114,192.168.1.112三台测试服务器的LNMP开发环境

	bash deploy_lnmp_docker_dev.sh --role deploy-lnmp-dev --hosts 192.168.1.113,192.168.1.114,192.168.1.112

	b、批量下线192.168.1.113,192.168.1.114,192.168.1.112三台测试服务器的LNMP开发环境下的docker、docker-compose

	bash deploy_lnmp_docker_dev.sh --role destroy-lnmp-dev --hosts 192.168.1.113,192.168.1.114,192.168.1.112

	c、批量清除安装脚本遗留的文件包

	bash deploy_lnmp_docker_dev.sh --role clean-cache --hosts 192.168.1.113,192.168.1.114,192.168.1.112

2、本地部署方式

	a、本机安装docker、docker-compose
	
	bash deploy_lnmp_docker_dev.sh --role install-lnmp-dev

	b、本机卸载

	bash deploy_lnmp_docker_dev.sh --role purge-lnmp-dev

## 问题和规划

1、代码实时更新脚本未完成,k8s部署脚本为完成

2、ansible 的hosts配置目前需要手动修改

3、代码自动打包上传更新脚本

4、upgrade.sh后续版本
