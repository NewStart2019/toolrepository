#!/bin/bash

# 下载并安装 all-in-one （需要联网）
bash -c "$(curl -s https://obbusiness-private.oss-cn-shanghai.aliyuncs.com/download-center/opensource/oceanbase-all-in-one/installer.sh)"
source ~/.oceanbase-all-in-one/bin/env.sh

# 快速部署 OceanBase database
# obd demo

/root/oceanbase-ce/bin/observer -r 127.0.0.1:2882:2881 \
  -p 2881 -P 2882 -z zone1 -n demo -c 1766005159 \
  -d /root/oceanbase-ce/store \
  -I 127.0.0.1 \
  -o __min_full_resource_pool_memory=1073741824,enable_syslog_wf=False,max_syslog_file_count=16,memory_limit=6G,system_memory=1G,cpu_count=62,datafile_size=2G,datafile_maxsize=8G,datafile_next=2G,log_disk_size=14G,enable_record_trace_log=False,enable_syslog_recycle=1

obshell daemon --ip 127.0.0.1 --port 2886