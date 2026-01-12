variable "TAG" {
  default = "latest"
  # 使用："${TAG}"
}

group "default" {
  targets = ["fileview",]
}
target "fileview" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-new"
  tags = ["zqh2021/kkfileview:4.4.0"]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}