# 安装包下载
    下载地址：wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-9.4.3-linux-x86_64.tar.gz
    手动下载或者命令下载皆可
    
    说明：安装包里面是二进制文件不依赖其他环境

# 上传 filebeat.servicxe 文件

    配置了安装目录、配置文件目录、数据目录、日志目录。
    目前都放在安装目录下面，自己根据自己的需求设置放置位置

    然后启动 filebeat服务
```shell
systemctl daemon-reload
systemctl start filebeat.service
```

# filebeat.yml 是配置推送的文件

    文件给了 nginx、system audit、springboot项目的json日志推送示例数据到 elasticsearch。详细内容看文件即可。
    input和module二选其一配置，不能同时使用。