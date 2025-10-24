#openEular 安装 isula
sudo dnf install -y isulad
sudo systemctl enable isulad --now

dnf search docker
dnf install docker
systemctl enable docker
systemctl status docker


# centos 安装
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
dnf -y install docker-ce docker-ce-cli containerd.io
systemctl enable docker
systemctl start docker
systemctl status docker