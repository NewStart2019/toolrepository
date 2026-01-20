#!/usr/bin/env bash

# 数据可视化与监控平台，主要用于将时间序列数据（如系统指标、应用性能、业务数据等）以图表、仪表盘等形式直观展示。
#       它本身不存储数据，而是通过连接各种 数据源（Data Sources） 来查询和展示数据。
# 安装
dnf install grafana
sudo setenforce 0

# 启动服务（systemd）
sudo systemctl start grafana-server
# 设置开机自启
sudo systemctl enable grafana-server
# 查看状态
sudo systemctl status grafana-server


# 纯手动启动 启动命令
#grafana/bin/grafana-server --homepath=/root/grafana \
#  --config=/root/grafana/conf/obd-grafana.ini \
#  --pidfile=/root/grafana/run/grafana.pid