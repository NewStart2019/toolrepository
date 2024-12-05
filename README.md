# ToolRepository

## 常识
1、可以使用shellcheck工具检测sh脚本是否错误，以及修正方法。 
```
shellcheck xxx.sh
```

## git lsf 使用技巧

## 问题

### 国外镜像不能下拉问题解决
    * 在镜像名称前加前缀 docker.m.daocloud.io

## 时区没有设置成功
    * 添加环境变量 TZ=Asia/Shanghai
    * 通过挂载的时候：- /etc/localtime:/etc/localtime:ro，确保本地有这个文件，centos默认没有这个文件，下面的命令可以创建
```shell
timedatectl set-timezone Asia/Shanghai
```