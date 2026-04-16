# 推荐使用 RHEL 仓库（Rocky 与 RHEL 完全兼容）
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf update -y
# 安装 docker 、 docker-compose
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
# 开启并开机自启动
sudo systemctl enable --now docker
sudo systemctl status docker   # 检查状态