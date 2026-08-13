# 推荐使用 RHEL 仓库（Rocky 与 RHEL 完全兼容）
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
sudo dnf update -y
# 安装 docker 、 docker-compose
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/local/bin/docker-compose
# 开启并开机自启动
sudo systemctl enable --now docker
sudo systemctl status docker   # 检查状态

# Rocky Linux 默认使用 nftables 作为防火墙后端，但 Docker 仍然依赖传统的 iptables (legacy) 命令来管理容器网络规则。当系统中 iptables
# 指向了 nftables 兼容层（即 iptables-nft），而内核中未加载对应的 nftables 模块或表结构不匹配时，
# Docker 在创建 bridge 网络的 PREROUTING 链时就会报 No such file or directory 错误

# 1. 同步整套内核包，让所有组件版本对齐
dnf distro-sync -y
# 重启
reboot
# 测试模块加载
modprobe xt_addrtype
modprobe br_netfilter
modprobe nf_nat
