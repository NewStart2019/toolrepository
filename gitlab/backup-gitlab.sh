#!/bin/bash

BACKUP_DIR="/opt/gitlab-backups"
DATE=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# 1. 触发 GitLab 内部备份
docker exec gitlab gitlab-backup create SKIP=artifacts

# 2. 获取最新备份文件名
LATEST_BACKUP=$(docker exec gitlab ls -t /var/opt/gitlab/backups/ | head -n1 | tr -d '\r\n')

# 3. 复制到宿主机
docker cp "gitlab:/var/opt/gitlab/backups/$LATEST_BACKUP" "$BACKUP_DIR/gitlab-backup-$DATE.tar"

# 4. 备份配置和 secrets
cp /srv/gitlab/config/gitlab.rb "$BACKUP_DIR/gitlab.rb-$DATE"
cp /srv/gitlab/config/gitlab-secrets.json "$BACKUP_DIR/gitlab-secrets-$DATE.json"

# 5. 清理 7 天前的备份（可选）
find "$BACKUP_DIR" -name "*.tar" -mtime +7 -delete
find "$BACKUP_DIR" -name "gitlab.rb-*" -mtime +7 -delete
find "$BACKUP_DIR" -name "gitlab-secrets-*" -mtime +7 -delete

echo "✅ GitLab backup completed: $BACKUP_DIR/gitlab-backup-$DATE.tar"