variable "TAG" {
  default = "latest"
  # 使用："${TAG}"
}

group "default" {
  targets = ["nginx",]
}
target "nginx" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile"
  # tags = ["172.16.0.197:8083/tool/ucm-nginx:1.27.5.1"]
  tags = ["zqh2021/ucm-nginx:1.27.5.1"]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}