一、文件及使用方式介绍

1、admin.conf k8s-prod 的kubeconfig文件

   a、使用方法参考第4点
   
   b、安装kubectl 工具

2、yaml k8s 服务调度配置文件

   a、当前目录下创建dev ， prod 目录
   
   b、根据需求生产预发布测试环境配置文件保存在dev ，生产环境保存在prod目录下

3、phpmyadmin-db 项目mysql数据库配置

   直接替换相关信息即可使用
  
4、mk-data-container.sh 将当前目录下文件及目录，做到镜像里面。同时，作为数据卷挂载到kubectl容器下使用

方法如下：
  a、sh mk-data-container.sh
  
  b、docker run --rm --volumes-from data docker.io/lachlanevenson/k8s-kubectl:v1.8.1 --kubeconfig /data/admin.conf create ns $namespaces
  
  c、docker run --rm --volumes-from data docker.io/lachlanevenson/k8s-kubectl:v1.8.1 --kubeconfig /data/admin.conf create secret docker-registry aliyun-sec -n $namespaces --docker-server=harbor.chen-123.com --docker-username=admin --docker-password=xxxx --docker-email=wp8155562@gmail.com
  
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

