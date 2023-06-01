#!/bin/bash

# GitLab Personal Access Token
personal_access_token=glpat-wQcDqYDZeDVnRxr6cXZh
# GitLab API Endpoint
api_endpoint=http://172.16.0.145:8929//api/v4/projects
# Project ID
project_id=4
# 项目状态可以从 CI/CD → Pipeline 的搜索框查看
pipeline_status=failed

# Get list of pipelines for project : 分页参数per_page=100
pipelines=$(curl --silent --header "Authorization: Bearer ${personal_access_token}" "${api_endpoint}/${project_id}/pipelines?status=${pipeline_status}" | jq '.[] .id')
echo $pipelines
# Loop through pipeline IDs and delete them
for pipeline in $pipelines
do
  curl --request DELETE --header "Authorization: Bearer ${personal_access_token}" "${api_endpoint}/${project_id}/pipelines/${pipeline}"
done
