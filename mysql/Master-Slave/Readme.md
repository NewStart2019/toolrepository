## [Warning] World-writable config file '/etc/mysql/conf.d/slave-gtid.cnf' is ignored

    chmod 644 /etc/mysql/conf.d/slave-gtid.cnf
    重启容器

## 注意

    配置文件带有文件编码或隐藏字符问题，建议用 Linux 工具查看并去除 BOM 或者本地使用 notepad修改编码 utf-8