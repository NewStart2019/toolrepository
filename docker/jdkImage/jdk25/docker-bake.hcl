variable "TAG" {
  default = "latest"
  # 使用："${TAG}"
}

group "default" {
  targets = ["jdk25",]
}
target "jdk25" {
  platforms = ["linux/amd64", "linux/arm64",]
  context    = "."
  dockerfile = "Dockerfile-alphineBig"
  tags = ["172.16.0.197:8083/tool/alpine_jdk25_special:1.3"]
  output = [
    "type=registry"
  ]
}