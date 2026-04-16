variable "TAG" {
  default = "latest"
  # 使用："${TAG}"
}

group "default" {
  targets = [
    "gradle25",
    "gradle21",
  ]
}

target "gradle25" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-gradle-jdk25"
  args = {
    DOCKER_VERSION = "29.3.1-dind-alpine3.23"
    VERSION = "25"            # 这里直接覆盖 Dockerfile 中的 ARG VERSION=11
    GRADLE_VERSION = "9.4.1"  # 这里直接覆盖 Dockerfile 中的 ARG GRADLE_VERSION=8.1.2
  }
  tags = [
    "zqh2021/docker_gradle:29-jdk25",
    "172.16.0.197:8083/zqh2021/docker_gradle:29-jdk25"
  ]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}

target "gradle21" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-gradle"
  args = {
    DOCKER_VERSION = "29.3.1-dind-alpine3.23"
    VERSION = "21"            # 这里直接覆盖 Dockerfile 中的 ARG VERSION=11
    GRADLE_VERSION = "8.12.1"  # 这里直接覆盖 Dockerfile 中的 ARG GRADLE_VERSION=8.1.2
  }
  tags = [
    "zqh2021/docker_gradle:29-jdk21",
    "172.16.0.197:8083/zqh2021/docker_gradle:29-jdk21"
  ]
  output = [
    "type=registry"
  ]
}