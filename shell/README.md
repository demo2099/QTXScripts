# nf-dns-watch.sh

Netflix 解锁守护脚本：定时检测 Netflix 解锁状态，未解锁时自动测速 AKDNS 节点并切换系统 DNS。

适用于 Alpine 3.21（BusyBox ash / OpenRC / musl libc），逻辑整理自 [akile-network/aktools](https://github.com/akile-network/aktools) 的 `akdns.sh` 菜单 4「一键测速并应用」。

## 工作流程

```
检测 Netflix 解锁状态（双标题判定，与 RegionRestrictionCheck 一致）
  ├─ 已解锁 → 记录日志，退出
  └─ 未解锁 → dig 并行测速所有 AKDNS 节点（UDP，全超时自动回退 TCP）
               → 按延迟升序排序
               → 依次切换候选节点并实测解锁：
                   切换 → 验证解析 → 复测 Netflix
                   能解锁即停（即"能解锁的节点里最快的那个"）
                   不能解锁 → 试下一个
               → 全部失败则还原原始 DNS，并提示去控制台配置
```

**以解锁为目标，不是以延迟最低为目标。** 延迟只用于决定尝试顺序：
先试最快的，能解锁就停；不能解锁就按延迟顺序继续试，直到找到能解锁的节点。

## 通知（可选）

全部节点都无法解锁时推送通知，并做了去重，避免刷屏：

- **首次失败** → 立即通知一次
- **持续失败** → 每 `NOTIFY_REPEAT_INTERVAL`（默认 5 小时）才再通知一次
- **恢复正常** → 通知一次，状态复位
- **一直正常** → 不发送任何通知

配置写在 `/etc/nf-dns-watch.conf`（**不要写进脚本**，密钥会随公开仓库泄露）：

```sh
chmod 600 /etc/nf-dns-watch.conf
cat > /etc/nf-dns-watch.conf <<'EOF'
NOTIFY_URL="https://your-bark-host/YOUR_KEY/title/body?group=example&ttl=600"
NOTIFY_REPEAT_INTERVAL=18000
EOF

nf-dns-watch.sh test-notify     # 发一条测试通知验证
```

脚本会把 `/title/body` 去掉得到 KEY 端点，改用 **POST JSON** 提交（`{"title","body","group","ttl"}`），
这样中文标题不需要 URL 编码。

状态保存在 `/var/lib/nf-dns-watch/state`：

```
STATE_STATUS=ok|fail
STATE_LAST_NOTIFY=<epoch>
```

删除该文件可重置通知状态（下次失败会立即通知）。

## 安装

```sh
apk add curl bind-tools
install -m755 nf-dns-watch.sh /usr/local/bin/nf-dns-watch.sh

nf-dns-watch.sh install-cron 5     # 每 5 分钟检测一次
```

## 命令

| 命令 | 作用 |
|---|---|
| `nf-dns-watch.sh run` | 检测一次（cron 调用入口） |
| `nf-dns-watch.sh force` | 跳过检测，强制测速并切换 DNS |
| `nf-dns-watch.sh test-speed` | 只测速看结果，不改任何配置 |
| `nf-dns-watch.sh test-notify` | 发送一条测试通知 |
| `nf-dns-watch.sh status` | 查看当前 DNS / Netflix / 定时任务状态 |
| `nf-dns-watch.sh restore` | 从最近一次备份还原 DNS |
| `nf-dns-watch.sh install-cron N` | 安装定时任务，每 N 分钟（1-59） |
| `nf-dns-watch.sh uninstall-cron` | 移除定时任务 |

## 自定义节点

默认内置 8 个 AKDNS 节点（与 akdns.sh 一致，硬编码）。如需覆盖，创建 `/etc/nf-dns-watch.conf`：

```sh
# 直接指定节点
DNS_LIST="1.2.3.4 5.6.7.8"

# 或从远程拉取（每行一个 IPv4，支持 # 注释）
DNS_LIST_URL="https://example.com/akdns-ips.txt"

# 其他可覆盖项
COUNT=5                # 每节点测速次数
TIMEOUT=1              # 单次查询超时（秒）
LOCK_RESOLV_CONF=0     # 是否 chattr +i 锁定 resolv.conf
```

## 日志

```sh
tail -f /var/log/nf-dns-watch.log
```

日志超过 512KB 会自动截断保留尾部 2000 行。备份位于 `/var/lib/nf-dns-watch/backup/`。

## 注意

- 切换 DNS 后若仍未解锁，说明该节点未为你的 IP 配置解锁服务，需到 [AKDNS 控制台](https://dns.akile.ai/console) 勾选
- musl libc 不支持 `options use-vc`，TCP 模式仅对部分应用生效
- 传输到 Linux 服务器后建议 `sed -i 's/\r$//'` 或 `tr -d '\r'` 清除 CRLF
