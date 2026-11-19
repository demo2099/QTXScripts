# nf-dns-watch.sh

Netflix 解锁守护脚本：定时检测 Netflix 解锁状态，未解锁时自动测速 AKDNS 节点并切换系统 DNS。

适用于 Alpine 3.21（BusyBox ash / OpenRC / musl libc），逻辑整理自 [akile-network/aktools](https://github.com/akile-network/aktools) 的 `akdns.sh` 菜单 4「一键测速并应用」。

## 工作流程

```
检测 Netflix 解锁状态（双标题判定，与 RegionRestrictionCheck 一致）
  ├─ 已解锁 → 记录日志，退出
  └─ 未解锁 → dig 并行测速所有 AKDNS 节点（UDP，全超时自动回退 TCP）
               → 选出延迟最低节点
               → 备份 /etc/resolv.conf（保留最近 20 份）
               → 原子写入新 DNS + chattr +i 锁定
               → 验证解析（失败自动回滚）
               → 复测 Netflix
```

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
