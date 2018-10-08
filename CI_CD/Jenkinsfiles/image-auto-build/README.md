一、文件及使用方式介绍
1、admin.conf k8s-prod 的kubeconfig文件

   a、使用方法参考第4点

   b、安装kubectl 工具

2、yaml k8s 服务部署配置文件

   a、当前目录下创建dev ， prod 目录

   b、根据需求生产预发布测试环境配置文件保存在dev ，生产环境保存在prod目录下

3、phpmyadmin-db 项目mysql数据库配置

   直接替换相关信息即可使用
  
4、mk-data-container.sh 将当前目录下文件及目录，做到镜像里面。同时，作为数据卷挂载到kubectl容器下使用

方法如下：

  a、sh mk-data-container.sh

  b、docker run --rm --volumes-from data docker.io/lachlanevenson/k8s-kubectl:v1.8.1 --kubeconfig /data/admin.conf create ns $namespaces

  c、docker run --rm --volumes-from data docker.io/lachlanevenson/k8s-kubectl:v1.8.1 --kubeconfig /data/admin.conf create secret docker-registry reg-sec -n $namespaces --docker-server=harbor.chen-123.com --docker-username=admin --docker-password=xxxxx --docker-email=wp8155562@gmail.com

  d、docker run --rm --volumes-from data docker.io/lachlanevenson/k8s-kubectl:v1.8.1 --kubeconfig /data/admin.conf create -f /data/dev/ -n $namespaces

二、替换参数说明

1、yaml 配置文件

PROJECT-NAME  项目名称替换变量

NAMESPACE。   项目所属namespace

REGISTER-IMAGE 项目镜像替换变量

MYSQL_HOST  mysql数据库主机地址替换变量

MYSQL_PORT  mysql数据库端口替换变量

MYSQL_USERNAME mysql数据库用户名替换变量

MYSQL_PASSWORD mysql数据库密码替换变量

PROJECT-DOMAIN 项目域名替换变量

PROJECT-NAME-DOMAIN phpmyadmin访问域名

三、镜像构建

1、变量说明

PROJECT_NAME 项目名称 代码目录 /opt/chen-123/www/html/PROJECT_NAME

GIT_SOURCE_ADDR 项目代码库ssh地址  

CC_EMAILS   邮件接收

NAME_SPACE k8s namespace

BASE_REGISTER_IMAGE   基础镜像

APP_REGISTER_IMAGE    包含代码的应用镜像

CALL_BACK_WEBHOOK   one-deply web hook 触发ci流程

2、脚本调用

curl -X POST --user "chen-123:bb537ca4dd1b3de4247737659e021ac2" -s https://jenkins-ci.chen-123.com/job/image-auto-build/buildWithParameters -d "PROJECT_NAME=php-apache&GIT_SOURCE_ADDR=git@gitlab.chen-123.com:noc/wordpress.git&CC_EMAILS=wp8155562@gmail.com&NAME_SPACE=backend&BASE_REGISTER_IMAGE=harbor.chen-123.com/noc/php-apache:php5.6.13-apache&APP_REGISTER_IMAGE=harbor.chen-123.com/noc/php-apache-app:php5.6.13.3-apache&CALL_BACK_WEBHOOK=http://www.phpdba.com"
