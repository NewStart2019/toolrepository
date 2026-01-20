variable "TAG" {
  default = "latest"
  # 使用："${TAG}"
}

group "default" {
  targets = ["base", "jdk21", "jdk21-ocr"]
}

target "base" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-alphine"
  tags = [
    "zqh2021/alpine-jdk21:1.0",
    "172.16.0.197:8083/zqh2021/alpine-jdk21:1.0"
  ]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}

target "jdk21" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-alphineBig"
  tags = [
    "zqh2021/alpine_jdk21_special_ocr_jdk21:1.4",
    "172.16.0.197:8083/zqh2021/alpine_jdk21_special_ocr_jdk21:1.4"
  ]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}

target "jdk21-ocr" {
  # 构建前拉取最新 base imagedocker buildx create
  pull       = true
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-alphineBig-ocr"
  tags = [
    "zqh2021/alpine_jdk21_special_ocr_jdk21:1.4",
    "172.16.0.197:8083/zqh2021/alpine_jdk21_special_ocr_jdk21:1.4"
  ]
  # 该配置表示构建后直接推送到 registry，不会加载到本地 Docker。
  # 本地测试：output = ["type=oci,dest=image.tar"]  # 导出为 OCI tar
  output = [
    "type=registry"
  ]
}