variable "TAG" {
  default = "latest"
  # 使用："${TAG}"
}

group "default" {
  targets = [
    # "ubuntu_ssh",
    "ubuntu_ssh_nvm",
  ]
}
target "ubuntu_ssh" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile"
  tags = [
    "zqh2021/ubuntu_ssh:26.04",
    "172.16.0.197:8083/zqh2021/ubuntu_ssh:26.04"
  ]
  args = {
    UBUNTU_VERSION = "26.04",
    PASSWORD       = "xxxx"
  }
  secret = [
    # 来源：本地文件 .rootpw
    # "id=rootpw,src=.rootpw"
    # 来源是环境变量 ROOT_PASSWORD
    "id=rootpw,env=ROOT_PASSWORD"
  ]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}

target "ubuntu_ssh_nvm" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-node"
  tags = [
    "zqh2021/ubuntu_ssh_nvm:26.04",
    "172.16.0.197:8083/zqh2021/ubuntu_ssh_nvm:26.04"
  ]
  args = {
    UBUNTU_VERSION = "26.04",
    PASSWORD       = "xxxx"
  }
  secret = [
    # 来源：本地文件 .rootpw
    # "id=rootpw,src=.rootpw"
    # 来源是环境变量 ROOT_PASSWORD
    "id=rootpw,env=ROOT_PASSWORD"
  ]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}