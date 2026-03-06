# macOS 本机 GCS 挂载（OpenClaw / rclone）

本文档仅保留 `rclone` 路线：在 macOS 将 GCS 存储桶挂载到本地目录，并映射 `OPENCLAW_STATE_DIR`。

## 架构

- 挂载命令：`rclone nfsmount`
- 控制脚本：`scripts/macos_mount_gcs_openclaw.sh`
- 运行模式：
  - `up`：后台启动挂载
  - `down`：停止并卸载
  - `restart`：先停止/卸载，再重新挂载
  - `ensure`：检查挂载是否可读；若已僵死则自动重挂
  - `status`：查看挂载、进程、launchd 状态
  - `launchctl`：显式管理 launchd 服务（install/start/stop/restart/uninstall/print）
- 长期运行：可选 `--install-launchd`（`KeepAlive + RunAtLoad`，支持重启自愈）

## 环境准备

1. 安装 `rclone`

```bash
brew install rclone
rclone version
```

2. 准备挂载目录（默认 `/opt/data`）

```bash
sudo mkdir -p /opt/data
sudo chown "$USER":staff /opt/data
```

3. 准备可写 cache 目录（脚本默认会自动创建）

```bash
mkdir -p "$HOME/.openclaw/cache/rclone-vfs"
```

## 配置

先配置一个 GCS remote（示例名：`openclaw-gcs`）：

```bash
rclone config
```

完成后先验证 remote 可读：

```bash
rclone lsd openclaw-gcs:openclawbot-data
```

如果这里失败，先修复凭据/权限，再进行挂载。

可选检查（确认 backend 正确）：

```bash
rclone config show openclaw-gcs | rg '^(type|provider|env_auth)\s*='
```

期望 `type = google cloud storage`。

## 挂载

在仓库根目录执行：

```bash
chmod +x scripts/macos_mount_gcs_openclaw.sh
export GCS_BUCKET_NAME=openclawbot-data
./scripts/macos_mount_gcs_openclaw.sh up \
  --remote openclaw-gcs \
  --mount-point /opt/data \
  --env-file .env
```

也可以不导出环境变量，直接通过参数传入：

```bash
./scripts/macos_mount_gcs_openclaw.sh restart \
  --remote openclaw-gcs \
  --bucket openclawbot-data \
  --mount-point /opt/data
```

说明：

- 脚本默认启用可写缓存：`--vfs-cache-mode full`
- 默认 cache 目录：`~/.openclaw/cache/rclone-vfs`
- `--env-file` 会自动写入或更新：

```bash
OPENCLAW_STATE_DIR=/opt/data
```

读写要求（必须）：

- 需要写入能力时，`--vfs-cache-mode` 必须是 `writes` 或 `full`
- 默认 `full`，如果手动改为 `off`/`minimal`，写入行为可能失败或不稳定

常用控制命令：

```bash
./scripts/macos_mount_gcs_openclaw.sh status --mount-point /opt/data
./scripts/macos_mount_gcs_openclaw.sh down --mount-point /opt/data
./scripts/macos_mount_gcs_openclaw.sh restart --mount-point /opt/data
./scripts/macos_mount_gcs_openclaw.sh ensure --mount-point /opt/data
./scripts/macos_mount_gcs_openclaw.sh up --force-remount --mount-point /opt/data
```

## 稳定运行

需要长期后台运行与异常自愈时，使用 launchd：

```bash
./scripts/macos_mount_gcs_openclaw.sh up \
  --remote openclaw-gcs \
  --mount-point /opt/data \
  --env-file .env \
  --install-launchd
```

状态检查：

```bash
./scripts/macos_mount_gcs_openclaw.sh status --mount-point /opt/data
launchctl print "gui/$UID/ai.openclaw.gcs-rclone-mount" >/dev/null && echo "launchd loaded"
```

也可以使用显式 `launchctl` 模式管理服务：

```bash
./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode install \
  --remote openclaw-gcs \
  --mount-point /opt/data

./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode start
./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode status
./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode print
./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode restart
./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode stop
./scripts/macos_mount_gcs_openclaw.sh launchctl --launchctl-mode uninstall
```

如果你的故障模式是 “`localhost:/... on /opt/data (nfs)` 还在，但 `ls /opt/data` 报 `nfs server ... not responding`”，优先执行：

```bash
./scripts/macos_mount_gcs_openclaw.sh ensure --mount-point /opt/data
```

这会自动执行：

- 检查 `/opt/data` 是否已挂载且可读
- 若挂载不存在或已僵死：停止已有挂载进程、强制卸载、再重新挂载
- 若已安装 launchd：优先通过 launchd 重新拉起

## 优化

可通过 `--rclone-arg` 追加推荐参数：

```bash
./scripts/macos_mount_gcs_openclaw.sh up \
  --remote openclaw-gcs \
  --bucket openclawbot-data \
  --mount-point /opt/data \
  --vfs-cache-mode full \
  --rclone-arg "--dir-cache-time=72h" \
  --rclone-arg "--poll-interval=1m" \
  --rclone-arg "--vfs-write-back=10s" \
  --rclone-arg "--buffer-size=16M"
```

推荐基线：

- `--vfs-cache-mode=full`（读写最稳）
- `--dir-cache-time=72h`（减少目录元数据请求）
- `--poll-interval=1m`（平衡实时性与开销）
- `--vfs-write-back=10s`（减少碎写）

## 排障与验证清单

排障：

- 挂载不成功：`tail -n 200 ~/Library/Logs/openclaw/gcs-rclone-mount.log`
- `status` 显示未挂载：先 `down` 再 `up --force-remount`
- 能读不能写：确认 `--vfs-cache-mode` 为 `writes` 或 `full`，并检查 cache 目录可写
- remote 访问失败：先执行 `rclone lsd <remote>:<bucket>` 验证凭据与权限
- `type = s3` 导致 GCS 访问异常：执行 `rclone config update <remote> type 'google cloud storage' env_auth true`
- `mount_nfs ... Operation not permitted`：优先调整 `/opt/data` 所有权到当前用户，再重试挂载

验证清单：

```bash
./scripts/macos_mount_gcs_openclaw.sh status --mount-point /opt/data
mount | grep " on /opt/data "
touch /opt/data/.rw-check && rm -f /opt/data/.rw-check
grep '^OPENCLAW_STATE_DIR=' .env
```
