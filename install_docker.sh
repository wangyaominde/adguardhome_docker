#!/bin/bash

# 检查脚本是否以root权限运行
if [ "$EUID" -ne 0 ]; then
  echo "请以root权限运行此脚本。"
  exit 1
fi

# 更新系统包
update_system() {
  echo "更新系统包..."
  if [ -x "$(command -v apt)" ]; then
    apt update && apt upgrade -y
  elif [ -x "$(command -v yum)" ]; then
    yum update -y
  else
    echo "不支持的包管理器。"
    exit 1
  fi
}

# 安装依赖包
install_dependencies() {
  echo "安装依赖包..."
  if [ -x "$(command -v apt)" ]; then
    apt install -y apt-transport-https ca-certificates curl software-properties-common
  elif [ -x "$(command -v yum)" ]; then
    yum install -y yum-utils device-mapper-persistent-data lvm2
  fi
}

# 添加Docker官方GPG密钥和存储库
setup_docker_repository() {
  echo "设置Docker存储库..."
  if [ -x "$(command -v apt)" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  elif [ -x "$(command -v yum)" ]; then
    curl -fsSL https://download.docker.com/linux/centos/gpg | gpg --dearmor -o /etc/pki/rpm-gpg/RPM-GPG-KEY-docker
    yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  fi
}

# 安装Docker CE
install_docker() {
  echo "安装Docker CE..."
  if [ -x "$(command -v apt)" ]; then
    apt update
    apt install -y docker-ce
  elif [ -x "$(command -v yum)" ]; then
    yum install -y docker-ce
  fi
}

# 启动并启用Docker服务
start_docker() {
  echo "启动Docker服务..."
  systemctl start docker
  systemctl enable docker
}

# 检查Docker安装
check_docker() {
  if [ -x "$(command -v docker)" ]; then
    echo "Docker安装成功！版本信息："
    docker --version
  else
    echo "Docker安装失败。"
    exit 1
  fi
}

# 主程序
update_system
install_dependencies
setup_docker_repository
install_docker
start_docker
check_docker

exit 0

