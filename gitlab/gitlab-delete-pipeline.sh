#!/bin/bash

#!/usr/bin/env bash
set -euo pipefail

GITLAB_URL="http://172.16.0.197:8929"\
# 注意过期时间是 2027-03-02
TOKEN="glpat-8SYjaMI8Ezd7o2mi50YZH286MQp1OjIH.01.0w0r79pq1"
PROJECT_ID="74"
PER_PAGE=15

echo "将保留项目 $PROJECT_ID 中最近更新的 $PER_PAGE 条 pipeline，其余删除"

# 保留的页数
PAGE=2
while true; do
  pipelines=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/pipelines?per_page=${PER_PAGE}&page=${PAGE}&order_by=updated_at&sort=desc")

  if [ "$(echo "$pipelines" | jq 'length')" -eq 0 ]; then
    echo "没有更多 pipeline 需要删除"
    break
  fi

  ids=$(echo "$pipelines" | jq -r '.[].id')

  for id in $ids; do
    echo "正在删除 pipeline $id"
    curl -s -X DELETE --header "PRIVATE-TOKEN: $TOKEN" \
      "$GITLAB_URL/api/v4/projects/$PROJECT_ID/pipelines/$id" >/dev/null || echo "删除 $id 失败（可能已被删）"
  done

#  ((PAGE++))
  sleep 0.3  # 防限速
done

echo "操作完成"
