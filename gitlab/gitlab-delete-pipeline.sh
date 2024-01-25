#!/bin/bash


# GitLab Personal Access Token
personal_access_token=glpat-wQcDqYDZeDVnRxr6cXZh
# GitLab API Endpoint
api_endpoint=http://172.16.0.145:8929//api/v4/projects
# Project ID
project_id=$1
# 项目状态可以从 CI/CD → Pipeline 的搜索框查看
pipeline_status=$2

if [ -z "$project_id" ]; then
  echo "请指定gitlab项目id，在项目目录下面的/Settings/General查看Project ID"
  exit 1
fi

if [ -z "$pipeline_status" ]; then
  echo "请指定pipeline_status，可以指定的值有：success、skipped、canceled、created、failed、manual、pending、skipped"
  exit 1
fi
# 字符串数组
statuses=("success" "skipped" "canceled" "created" "failed" "manual" "pending" "skipped")
# 判断传入的参数是否在数组中
# shellcheck disable=SC2199
# shellcheck disable=SC2076
if ! [[  " ${statuses[@]} " =~ " ${pipeline_status} " ]]; then
  echo "状态参数错误，可以指定的值：success、skipped、canceled、created、failed、manual、pending、skipped"
  exit 1
fi

# Get list of pipelines for project : 分页参数per_page=100。分页最大只能100
pipelines=$(curl --silent --header "Authorization: Bearer ${personal_access_token}" "${api_endpoint}/${project_id}/pipelines?per_page=100&status=${pipeline_status}" | jq '.[] .id')
echo $pipelines
# Loop through pipeline IDs and delete them
for pipeline in $pipelines
do
  curl --request DELETE --header "Authorization: Bearer ${personal_access_token}" "${api_endpoint}/${project_id}/pipelines/${pipeline}"
done
