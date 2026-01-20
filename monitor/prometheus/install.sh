#!/usr/bin/env bash

bashprometheusd.sh --config.file=/root/prometheus/prometheus.yaml \
    --web.listen-address=0.0.0.0:9090 \
    --storage.tsdb.path=/root/prometheus/data \
    --web.enable-lifecycle \
    --web.config.file=/root/prometheus/web_config.yaml \
    --daemon