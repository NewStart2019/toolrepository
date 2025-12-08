#!/bin/bash

# 检查是否以 root 运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请以 root 用户或使用 sudo 运行此脚本。"
  exit 1
fi

# 提示输入用户名
read -p "请输入要创建的用户名（默认 info）: " USERNAME
USERNAME=${USERNAME:-info}

# 检查用户是否已存在
if id "$USERNAME" &>/dev/null; then
  echo "⚠️ 用户 '$USERNAME' 已存在。"
  exit 1
fi

# 提示输入密码
read -s -p "请输入 '$USERNAME' 的密码(默认 xxzx2025): " PASSWORD
PASSWORD=${PASSWORD:-xxzx2025}
echo
read -s -p "请再次输入密码确认(默认 xxzx2025): " PASSWORD2
PASSWORD2=${PASSWORD2:-xxzx2025}
echo

if [ "$PASSWORD" != "$PASSWORD2" ]; then
  echo "❌ 两次密码不一致！"
  exit 1
fi

# 自动检测系统类型并确定目标组 q安静模式，E启用扩展正则表达式，i忽略大小写
if grep -qEi "debian|ubuntu" /etc/os-release; then
  TARGET_GROUP="sudo"
elif grep -qEi "centos|rocky|fedora|rhel|red hat|openEuler" /etc/os-release; then
  TARGET_GROUP="wheel"
else
  echo "⚠️ 无法明确识别系统类型。默认尝试使用 'sudo' 组。"
  TARGET_GROUP="sudo"
fi

# ✅ 新增：检查目标组是否存在
if ! getent group "$TARGET_GROUP" > /dev/null 2>&1; then
  echo "❌ 目标权限组 '$TARGET_GROUP' 不存在！"
  echo "   请先确保系统中已安装 sudo 并配置了该组（例如运行 'apt install sudo' 或 'dnf install sudo'）。"
  exit 1
fi

# 创建用户
echo "🔧 正在创建用户 '$USERNAME' ..."
if ! useradd -m -s /bin/bash "$USERNAME"; then
  echo "❌ 创建用户失败。"
  exit 1
fi

# 设置密码
echo "$USERNAME:$PASSWORD" | chpasswd

# 将用户加入权限组
echo "➕ 将用户 '$USERNAME' 加入 '$TARGET_GROUP' 组..."
if ! usermod -aG "$TARGET_GROUP" "$USERNAME"; then
  echo "❌ 无法将用户加入 '$TARGET_GROUP' 组。"
  exit 1
fi

# 验证是否成功加入组
if groups "$USERNAME" | grep -qw "$TARGET_GROUP"; then
  echo "✅ 用户 '$USERNAME' 创建成功，并已加入 '$TARGET_GROUP' 组，具备 sudo 权限。"
  echo "💡 提示：用户需重新登录后 sudo 权限才会生效。"
else
  echo "❌ 验证失败：用户未正确加入 '$TARGET_GROUP' 组。"
  exit 1
fi