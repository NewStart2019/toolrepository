## [Warning] World-writable config file '/etc/mysql/conf.d/slave-gtid.cnf' is ignored

    chmod 644 /etc/mysql/conf.d/slave-gtid.cnf
    重启容器

## 注意

    配置文件带有文件编码或隐藏字符问题，建议用 Linux 工具查看并去除 BOM 或者本地使用 notepad修改编码 utf-8


## 经验

    * MySQL9和mysql8之间实现主从复制没有问题。
    * 先锁住主数据库所有数据，然后复制数据到从数据库，然后开启主从复制，最后释放主库的锁。