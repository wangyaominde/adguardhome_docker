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

# 配置国内镜像源
configure_mirror() {
  echo "选择Docker国内镜像源："
  echo "1. 腾讯云"
  echo "2. 阿里云"
  echo "3. 不配置国内镜像源"
  read -p "请输入选项 (1/2/3): " choice

  case $choice in
    1)
      echo "使用腾讯云镜像源..."
      mirror_url="https://mirror.ccs.tencentyun.com"
      ;;
    2)
      echo "使用阿里云镜像源..."
      mirror_url="https://registry.aliyuncs.com"
      ;;
    3)
      echo "不使用国内镜像源。"
      return
      ;;
    *)
      echo "无效选项，默认不配置国内镜像源。"
      return
      ;;
  esac

  mkdir -p /etc/docker
  cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": ["$mirror_url"]
}
EOF

  echo "重启Docker以应用镜像源配置..."
  systemctl restart docker
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

# 自动申请证书
request_certificate() {
  echo "开始申请证书..."
  read -p "请输入域名: " domain
  if [ -z "$domain" ]; then
    echo "域名不能为空，退出证书申请。"
    return
  fi

  echo "检测域名DNS解析..."
  resolved_ip=$(dig +short $domain | head -n 1)
  if [ -z "$resolved_ip" ]; then
    echo "域名解析失败，请检查DNS设置。"
    return
  fi

  echo "域名解析成功: $resolved_ip"

  echo "安装Certbot..."
  if [ -x "$(command -v apt)" ]; then
    apt install -y certbot
  elif [ -x "$(command -v yum)" ]; then
    yum install -y certbot
  fi

  attempts=0
  max_attempts=5

  while [ $attempts -lt $max_attempts ]; do
    echo "申请证书... (尝试次数: $((attempts+1)))"
    certbot certonly --standalone -d $domain --agree-tos -m admin@$domain --non-interactive

    cert_path="/etc/letsencrypt/live/$domain"
    if [ -d "$cert_path" ]; then
      echo "证书申请成功，证书路径: $cert_path"
      mkdir -p ~/certificates
      cp -r $cert_path ~/certificates/
      echo "证书已保存到 ~/certificates/$domain"
      return
    fi

    attempts=$((attempts+1))
    if [ $attempts -lt $max_attempts ]; then
      echo "证书申请失败，等待10秒后重试..."
      sleep 10
    fi
  done

  echo "证书申请失败，已尝试 $max_attempts 次，请检查日志并确认域名设置正确。"
}

# 主程序
update_system
install_dependencies
setup_docker_repository
install_docker
start_docker
configure_mirror
check_docker
request_certificate

exit 0

