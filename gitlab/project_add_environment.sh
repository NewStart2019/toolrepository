#!/bin/bash
# 防止未定义变量或管道错误被静默忽略
set -euo pipefail

# ==================== 配置信息 ====================
GITLAB_URL="http://172.16.0.197:8929"
# 注意过期时间是 2027-03-02
TOKEN="glpat-8SYjaMI8Ezd7o2mi50YZH286MQp1OjIH.01.0w0r79pq1"
PROJECT_ID="42"

# 隐藏数据格式如下
#{
#    "id": 148,
#    "key": "testpass",
#    "value": null,
#    "description": "ceshi",
#    "variable_type": "env_var",
#    "protected": false,
#    "masked": true,
#    "raw": true, <======
#    "environment_scope": "*",
#    "hidden": true
#}

# 变量列表格式: KEY | VALUE | PROTECTED | MASKED | HIDDEN | RAW | ENVIRONMENT_SCOPE | DESCRIPTION
#  ENVIRONMENT_SCOPE: dev pro zhonjian
VARIABLES=(
  "TARGET_SERVER|172.16.0.227|false|false|false|false|dev|"
  "PASSWORD|sssss|false|true|true|false|dev|"
)

# ==================== 函数定义 ====================
# POST → 判断 HTTP 状态码 → 409 时自动 PUT
upsert_variable() {
  local key="$1" value="$2" protected="$3" masked="$4" hidden="$5" $raw="$6" scope="$7" description="$8"

  # 公共参数
  local params=(
    --data-urlencode "value=${value}"
    --data-urlencode "protected=${protected}"
    --data-urlencode "masked=${masked}"
    --data-urlencode "hidden=${hidden}"
    --data-urlencode "raw=$raw"
    --data-urlencode "environment_scope=${scope}"
    --data-urlencode "description=${description}"
    --data-urlencode "variable_type=env_var"
    --data-urlencode "filter[environment_scope]=${scope}"
  )

  # ---------- POST 创建 ----------
  local resp_file http_code post_body
  resp_file=$(mktemp)
  http_code=$(curl --silent --write-out "%{http_code}" \
    --output "$resp_file" \
    --request POST \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/variables" \
    --header "PRIVATE-TOKEN: ${TOKEN}" \
    --data-urlencode "key=${key}" \
    "${params[@]}")
  post_body=$(cat "$resp_file")
  rm -f "$resp_file"

  # 兼容判断：409 或 400+already been taken 均视为"已存在"
  local is_conflict=false
  if [[ "$http_code" == "409" ]]; then
    is_conflict=true
  elif [[ "$http_code" == "400" ]] && echo "$post_body" | grep -qi "already been taken"; then
    is_conflict=true
  fi

  if [[ "$http_code" == "201" ]]; then
    echo "✅ [新建] ${key} (scope: ${scope})"
    return 0
  elif [[ "$is_conflict" == "false" ]]; then
    echo "❌ [失败] ${key} 创建失败 (HTTP ${http_code}): ${post_body}"
    return 1
  fi

  # ---------- PUT 更新 ----------
  local encoded_key put_body
  encoded_key=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$key', safe=''))")
#  encoded_key=$(printf '%s' "$key" | sed 's/\./%2E/g; s/\//%2F/g; s/ /%20/g')

  resp_file=$(mktemp)
  http_code=$(curl --silent --write-out "%{http_code}" \
    --output "$resp_file" \
    --request PUT \
    "${GITLAB_URL}/api/v4/projects/${PROJECT_ID}/variables/${encoded_key}" \
    --header "PRIVATE-TOKEN: ${TOKEN}" \
    --data-urlencode "filter[environment_scope]=${scope}" \
    "${params[@]}")
  put_body=$(cat "$resp_file")
  rm -f "$resp_file"

  if [[ "$http_code" == "200" ]]; then
    echo "🔄 [更新] ${key} (scope: ${scope})"
    return 0
  else
    echo "❌ [失败] ${key} scope=${scope}更新失败 (HTTP ${http_code}): ${put_body}"
    return 1
  fi
}

# ==================== 主循环 ====================
echo "🚀 开始批量处理 GitLab CI/CD 变量 (Project ID: ${PROJECT_ID})"
echo "=============================================="

success=0
fail=0
for var in "${VARIABLES[@]}"; do
  IFS='|' read -r key value protected masked hidden raw scope description <<< "$var"
  if upsert_variable "$key" "$value" "$protected" "$masked" "$hidden" "$raw" "$scope" "$description"; then
    success=$((success + 1))          # 推荐：算术赋值永远返回 0
  else
    fail=$((fail+1))
  fi
  echo "处理成功 $success"
done

echo "=============================================="
echo "📊 完成: 成功 ${success} | 失败 ${fail} | 总计 ${#VARIABLES[@]}"