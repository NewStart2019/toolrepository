# Zabbix 
    是一个linux服务器监控工具，可以监控linux服务器的硬件、软件、网络、系统、进程、文件、数据库、虚拟机等

## Zabbix agent
    zabbix客户端
    安装：yum install zabbix-agent
    修改service：vim /usr/lib/systemd/system/zabbix-agent.service
```text
[Unit]
Description=Zabbix Monitor Agent
After=syslog.target network.target

[Service]
Type=simple
# 这里指定了 配置文件地址
ExecStart=/usr/sbin/zabbix_agentd -c /etc/zabbix/zabbix_agentd.conf -f
# 这里改成以root用户权限启动
User=root

[Install]
WantedBy=multi-user.target
···
    配置文件：vim /etc/zabbix/zabbix_agentd.conf
```text
AllowRoot=1
LogType=file
LogFile=/mydata/zabbix_agent/zabbix_agent.log
DebugLevel=3
Server=172.16.0.175
ServerActive=172.16.0.175:10051
Hostname=jtjc_data
ListenPort=10050
ListenIP=0.0.0.0
StartAgents=1
```
    启动：systemctl start zabbix-agent
    停止：systemctl stop zabbix-agent
    重启：systemctl restart zabbix-agent
    查看状态： systemctl status zabbix-agent
    开启防火墙
```shell
firewall-cmd --zone=public --add-port=10050/tcp --permanent
firewall-cmd --reload
```

## Zabbix server
    zabbix服务器，负责收集监控数据，管理监控项，生成报警信息
    安装：yum install zabbix-server-mysql zabbix-web-mysql zabbix-apache-conf zabbix-sql-scripts
    启动：systemctl start zabbix-server
    停止：systemctl stop zabbix-server
    配置文件：/etc/zabbix/zabbix_server.conf

## Zabbix web
    zabbix web页面，负责展示监控数据，管理监控项，生成报警信息
    安装：yum install zabbix-web-mysql
    启动：systemctl start httpd
    停止：systemctl stop httpd
    配置文件：/etc/httpd/conf.d/zabbix.conf
