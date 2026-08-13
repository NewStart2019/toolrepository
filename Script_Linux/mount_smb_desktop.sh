#!/bin/bash
set -e

# ===================== SMB永久挂载到UOS桌面脚本（幂等版） =====================
# 功能：安全配置fstab，凭据文件保存账号密码，挂载点在用户桌面
# 幂等：重复执行不会重复安装/创建/写入
# 必须sudo执行
# =============================================================================

# ---------- 颜色输出 ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ---------- 权限检查 ----------
if [[ $EUID -ne 0 ]]; then
    error "必须使用 sudo bash $0 运行此脚本"
fi

# 获取普通用户（sudo原始用户）
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(eval echo "~$REAL_USER")

# 识别UOS桌面目录 中文/英文
if [[ -d "${REAL_HOME}/桌面" ]]; then
    DESKTOP="${REAL_HOME}/桌面"
else
    DESKTOP="${REAL_HOME}/Desktop"
fi

# ---------- 默认值配置（可按需修改） ----------
DEFAULT_SMB_IP="172.16.0.175"
DEFAULT_SMB_SHARE="ShareDirectory/魏姣"
DEFAULT_SMB_USER="administrator"
DEFAULT_MOUNT_NAME="魏姣"

# ---------- 交互输入（带默认值） ----------
echo "============================================"
echo "  SMB 共享永久挂载配置（直接回车使用默认值）"
echo "============================================"

read -p "请输入SMB服务器IP [默认: ${DEFAULT_SMB_IP}]: " SMB_IP
SMB_IP=${SMB_IP:-${DEFAULT_SMB_IP}}

read -p "请输入共享文件夹名称 [默认: ${DEFAULT_SMB_SHARE}]: " SMB_SHARE
SMB_SHARE=${SMB_SHARE:-${DEFAULT_SMB_SHARE}}

read -p "SMB登录用户名 [默认: ${DEFAULT_SMB_USER}]: " SMB_USER
SMB_USER=${SMB_USER:-${DEFAULT_SMB_USER}}

# 密码必须输入，循环校验
while true; do
    read -sp "SMB登录密码（必填，不能为空）: " SMB_PASS
    echo ""
    if [[ -n "${SMB_PASS}" ]]; then
        break
    fi
    warn "密码不能为空，请重新输入"
done

read -p "挂载文件夹名称（将出现在桌面）[默认: ${DEFAULT_MOUNT_NAME}]: " MOUNT_NAME
MOUNT_NAME=${MOUNT_NAME:-${DEFAULT_MOUNT_NAME}}

MOUNT_POINT="${DESKTOP}/${MOUNT_NAME}"
CREDS_FILE="/etc/smb_${SMB_IP}_${SMB_SHARE}.cred"

# ---------- 配置信息确认 ----------
echo ""
echo "===== 配置信息确认 ====="
echo "服务器地址:    ${SMB_IP}"
echo "共享名:        ${SMB_SHARE}"
echo "挂载位置:      ${MOUNT_POINT}"
echo "账号:          ${SMB_USER}"
echo "密码:          ********（已输入）"
read -p "确认以上信息？[Y/n] " CONFIRM
CONFIRM=${CONFIRM:-Y}
if [[ "${CONFIRM^^}" != "Y" ]]; then
    info "用户取消，退出"
    exit 0
fi

# ---------- 1. 安装 cifs-utils（幂等：已安装则跳过） ----------
echo ""
info "[1/6] 检查 cifs-utils 安装状态"
if dpkg -l | grep -q "^ii.*cifs-utils"; then
    info "cifs-utils 已安装，跳过"
else
    info "正在安装 cifs-utils..."
    apt update -qq
    apt install -y cifs-utils
    info "cifs-utils 安装完成"
fi

# ---------- 2. 创建挂载目录（幂等：已存在则跳过） ----------
echo ""
info "[2/6] 检查桌面挂载目录"
if [[ -d "${MOUNT_POINT}" ]]; then
    info "目录已存在，跳过创建：${MOUNT_POINT}"
else
    mkdir -p "${MOUNT_POINT}"
    info "目录已创建：${MOUNT_POINT}"
fi
# 无论是否新建，都确保归属正确
chown "${REAL_USER}:${REAL_USER}" "${MOUNT_POINT}"

# ---------- 3. 生成凭据文件（幂等：已存在则跳过） ----------
echo ""
info "[3/6] 检查安全凭据文件"
if [[ -f "${CREDS_FILE}" ]]; then
    warn "凭据文件已存在，跳过创建：${CREDS_FILE}"
    warn "如需更新密码，请手动删除后重跑：sudo rm -f ${CREDS_FILE}"
else
    cat > "${CREDS_FILE}" <<EOF
username=${SMB_USER}
password=${SMB_PASS}
EOF
    chmod 600 "${CREDS_FILE}"
    info "凭据文件已创建并设置权限600：${CREDS_FILE}"
fi

# ---------- 4. 获取用户 uid/gid ----------
USER_UID=$(id -u "${REAL_USER}")
USER_GID=$(id -g "${REAL_USER}")

# ---------- 5. 写入 /etc/fstab（幂等：已存在则跳过） ----------
echo ""
info "[4/6] 检查 /etc/fstab 配置"
FSTAB_LINE="//${SMB_IP}/${SMB_SHARE}  ${MOUNT_POINT}  cifs  credentials=${CREDS_FILE},uid=${USER_UID},gid=${USER_GID},iocharset=utf8,_netdev,x-systemd.automount  0  0"

if grep -qF "//${SMB_IP}/${SMB_SHARE}" /etc/fstab; then
    warn "fstab 中已存在该 SMB 配置，跳过写入"
else
    # 备份 fstab（仅首次写入时备份）
    cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d_%H%M%S)
    echo "${FSTAB_LINE}" >> /etc/fstab
    info "fstab 配置已添加，原文件已备份"
fi

# ---------- 6. 执行挂载（幂等：已挂载则跳过） ----------
echo ""
info "[5/6] 检查挂载状态"
if mountpoint -q "${MOUNT_POINT}"; then
    info "已挂载，跳过：${MOUNT_POINT}"
else
    info "执行挂载..."
    systemctl daemon-reload
    if mount "${MOUNT_POINT}" 2>/tmp/mount_err; then
        info "挂载成功"
    else
        warn "挂载命令返回非零，可能为 systemd automount 按需挂载模式"
        warn "错误信息：$(cat /tmp/mount_err 2>/dev/null)"
    fi
fi

# ---------- 完成 ----------
echo ""
echo "============================================"
info "✅ 配置完成！"
echo "============================================"
echo "挂载路径：${MOUNT_POINT}"
echo "凭据文件：${CREDS_FILE}"
echo ""
echo "常用排错命令："
echo "  df -h                           查看挂载列表"
echo "  sudo mount -v ${MOUNT_POINT}    调试挂载报错"
echo "  sudo umount ${MOUNT_POINT}      卸载共享盘"
echo ""
echo "提示：重启电脑桌面会自动出现该共享目录"
echo "      重复执行本脚本不会重复安装/创建/写入"