#!/bin/sh
# ============================================================
# nf-dns-watch.sh v1.0 - Netflix 解锁守护 + AKDNS 自动切换
# 适用于 Alpine 3.21（BusyBox ash / OpenRC / musl libc）
#
# 逻辑整理自 akdns.sh v3.0.0（菜单 4「一键测速并应用」）：
#   检测 Netflix 是否解锁
#     ├─ 已解锁 → 记录日志，退出
#     └─ 未解锁 → dig 测速所有 AKDNS 节点（UDP，全超时自动回退 TCP）
#                 → 选出延迟最低节点
#                 → 备份并接管 /etc/resolv.conf（chattr +i 锁定防覆盖）
#                 → 验证系统解析 → 复测 Netflix
#
# 依赖（Alpine 3.21）:
#   apk add curl bind-tools
#
# 用法:
#   nf-dns-watch.sh run              检测一次（cron 调用入口）
#   nf-dns-watch.sh force            无论 Netflix 状态都强制测速并换 DNS
#   nf-dns-watch.sh test-speed       只测速看结果，不改任何系统配置
#   nf-dns-watch.sh install-cron 5   安装定时任务（每 5 分钟，参数可改分钟数）
#   nf-dns-watch.sh uninstall-cron   移除定时任务
#   nf-dns-watch.sh restore          从最近一次备份还原 resolv.conf
#   nf-dns-watch.sh status           查看当前 DNS 与 Netflix 状态
#
# 节点列表:
#   默认内置 8 个 AKDNS 节点（与 akdns.sh 一致，均为硬编码）。
#   如需自定义，创建 /etc/nf-dns-watch.conf：
#     DNS_LIST="1.2.3.4 5.6.7.8"                       # 直接指定
#     DNS_LIST_URL="https://example.com/ips.txt"       # 远程拉取（每行一个 IP）
#     COUNT=5 / TIMEOUT=1 / LOCK_RESOLV_CONF=0         # 其他可覆盖项
# ============================================================

set -u

# cron 环境 PATH 往往很短，显式补齐，确保能找到 dig / curl / chattr
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"
export PATH

# ---- 全局配置（整理自 akdns.sh）----
BACKUP_DIR="/var/lib/nf-dns-watch/backup"
LOG_FILE="/var/log/nf-dns-watch.log"
LOCK_FILE="/var/run/nf-dns-watch.lock"
DOMAIN="www.google.com"          # 测速用域名
COUNT=5                          # 每个节点测速次数
TIMEOUT=1                        # 单次查询超时（秒）
LOCK_RESOLV_CONF=1               # 应用后 chattr +i 锁定，防 dhcp/udhcpc 覆盖

# Netflix 解锁判定用的浏览器 UA（Netflix 会拦截默认 curl UA）
NF_UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

# AKDNS 控制台（未解锁时的提示）
CONSOLE_URL="https://dns.akile.ai/console"

# AKDNS 节点列表（默认值，同 akdns.sh，空格分隔）
# 可在 /etc/nf-dns-watch.conf 里覆盖 DNS_LIST，或用 DNS_LIST_URL 远程拉取
DNS_LIST="
66.66.66.66
45.207.157.146
108.160.138.51
139.180.133.239
45.76.83.113
45.76.71.83
45.63.99.176
166.0.199.207
"

# ---- 可选外部配置 ----
# 存在则加载，可覆盖上面任意变量，例如：
#   DNS_LIST="1.1.1.1 2.2.2.2"
#   DNS_LIST_URL="https://example.com/akdns-ips.txt"   # 每行一个 IP
#   COUNT=3
#   TIMEOUT=2
#   LOCK_RESOLV_CONF=0
CONF_FILE="${NF_DNS_CONF:-/etc/nf-dns-watch.conf}"
if [ -f "$CONF_FILE" ]; then
  # shellcheck source=/dev/null
  . "$CONF_FILE"
fi

# ---- 运行时状态 ----
BEST_DNS=""
DNS_USE_TCP=0

# ============================================================
# 日志
# ============================================================
log() {
  line="$(date '+%Y-%m-%d %H:%M:%S') $*"
  echo "$line"
  # 日志超 512KB 时截断保留尾部 2000 行
  if [ -f "$LOG_FILE" ] && [ "$(wc -c < "$LOG_FILE" 2>/dev/null || echo 0)" -gt 524288 ]; then
    tail -n 2000 "$LOG_FILE" > "$LOG_FILE.tmp" 2>/dev/null && mv "$LOG_FILE.tmp" "$LOG_FILE"
  fi
  echo "$line" >> "$LOG_FILE" 2>/dev/null || true
}

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "[错误] 缺少命令: $1，请先安装: apk add $2"
    return 1
  fi
  return 0
}

# ============================================================
# Netflix 解锁检测
# 返回 0 = 已解锁，1 = 未解锁/不可达
# ============================================================
check_netflix() {
  # 与 RegionRestrictionCheck 一致的判定方式：
  # 81280792 为非自制剧，70143836 为自制剧；均返回 200 才算完整解锁
  c1=$(curl -4 -sL -A "$NF_UA" -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 "https://www.netflix.com/title/81280792" 2>/dev/null)
  c2=$(curl -4 -sL -A "$NF_UA" -o /dev/null -w '%{http_code}' --connect-timeout 8 --max-time 20 "https://www.netflix.com/title/70143836" 2>/dev/null)
  if [ "$c1" = "200" ] && [ "$c2" = "200" ]; then
    log "[检测] Netflix: 已解锁 (非自制剧 200 / 自制剧 200)"
    return 0
  fi
  if [ "$c1" = "200" ] && [ "$c2" = "404" ]; then
    log "[检测] Netflix: 仅自制剧 (非自制剧 $c1 / 自制剧 $c2)，视为未解锁"
    return 1
  fi
  if [ "$c1" = "403" ] || [ "$c2" = "403" ]; then
    log "[检测] Netflix: 被封锁 (HTTP 403)"
    return 1
  fi
  log "[检测] Netflix: 未解锁 (非自制剧 ${c1:-000} / 自制剧 ${c2:-000})"
  return 1
}

# ============================================================
# 测速逻辑（移植自 akdns.sh measure_dns_transport）
# $1=传输标签  $2=dig 额外参数（空 或 +tcp）
# 输出: 按延迟升序的 "avg_ms dns_ip" 行；avg=1000 表示全部超时
# ============================================================
measure_dns_transport() {
  extra="$2"
  tmpdir=$(mktemp -d) || return 1

  # 每次查询只把耗时写入独立文件（文件名含 IP），避免把 IP 交给 awk 做数组下标
  # ——busybox awk 会把 "108.160.138.51" 这类字符串按数字处理，导致 IP 被截断
  for dns in $DNS_LIST; do
    i=1
    while [ "$i" -le "$COUNT" ]; do
      (
        t=$(dig "@$dns" "$DOMAIN" $extra +stats +time="$TIMEOUT" +tries=1 2>/dev/null | awk '/Query time/ {print $4; exit}')
        case "$t" in
          ''|*[!0-9]*) t=1000 ;;
        esac
        echo "$t"
      ) > "$tmpdir/${dns}_${i}" &
      i=$((i + 1))
    done
  done
  wait

  # 逐节点求平均，输出 "平均耗时 IP"，再按数值升序排序
  for dns in $DNS_LIST; do
    avg=$(cat "$tmpdir/${dns}_"* 2>/dev/null | awk '{ s += $1; n++ } END { if (n > 0) printf "%d", s / n; else printf "1000" }')
    echo "${avg:-1000} $dns"
  done | sort -n

  rm -rf "$tmpdir"
}

# 可选：从 DNS_LIST_URL 动态拉取节点列表（每行一个 IPv4，支持 # 注释）
# 拉取失败时保留当前 DNS_LIST 不变
load_dns_list() {
  [ -n "${DNS_LIST_URL:-}" ] || return 0
  fetched=$(curl -4 -s --connect-timeout 8 --max-time 15 "$DNS_LIST_URL" 2>/dev/null | grep -oE '^[[:space:]]*[0-9]{1,3}(\.[0-9]{1,3}){3}' | tr -d ' ' | head -50)
  if [ -n "$fetched" ]; then
    DNS_LIST="$fetched"
    log "[配置] 已从 $DNS_LIST_URL 拉取节点: $(echo "$DNS_LIST" | wc -l) 个"
  else
    log "[配置] 从 $DNS_LIST_URL 拉取失败，沿用内置节点列表"
  fi
}

# 测速选最优：UDP 优先，全部超时自动回退 TCP（移植自 akdns.sh run_speed_test）
find_best_dns() {
  need_cmd dig bind-tools || return 1
  load_dns_list
  BEST_DNS=""
  DNS_USE_TCP=0

  log "[测速] UDP 模式测速中 (域名: $DOMAIN, 每节点 ${COUNT} 次, 超时 ${TIMEOUT}s)..."
  result=$(measure_dns_transport udp "")

  best_avg=$(echo "$result" | head -n1 | awk '{print $1}')
  # UDP 全部超时 → 回退 TCP（常见于网络封锁 UDP/53）
  if [ -z "$result" ] || [ "${best_avg:-1000}" -ge 1000 ]; then
    log "[测速] UDP 全部超时，尝试 TCP 模式..."
    tcp_result=$(measure_dns_transport tcp "+tcp")
    tcp_best_avg=$(echo "$tcp_result" | head -n1 | awk '{print $1}')
    if [ -n "$tcp_result" ] && [ "${tcp_best_avg:-1000}" -lt 1000 ]; then
      result="$tcp_result"
      DNS_USE_TCP=1
      log "[测速] TCP 模式可用"
      log "[警告] Alpine(musl) 系统解析器不支持 options use-vc，TCP 仅对部分应用生效"
    fi
  fi

  echo "$result" | while read -r avg dns; do
    if [ "$avg" -ge 1000 ]; then
      log "[测速]   $dns  超时"
    else
      log "[测速]   $dns  ${avg}ms"
    fi
  done

  best_avg=$(echo "$result" | head -n1 | awk '{print $1}')
  best_dns=$(echo "$result" | head -n1 | awk '{print $2}')

  if [ -z "$best_dns" ] || [ "${best_avg:-1000}" -ge 1000 ]; then
    log "[测速] 所有 AKDNS 节点 UDP/TCP 均超时"
    return 1
  fi

  BEST_DNS="$best_dns"
  log "[测速] 最优节点: $BEST_DNS (${best_avg}ms$( [ "$DNS_USE_TCP" = "1" ] && echo ", TCP" ))"
  return 0
}

# ============================================================
# 备份（精简自 akdns.sh do_backup）
# ============================================================
backup_resolv() {
  mkdir -p "$BACKUP_DIR" || return 1
  chmod 700 "$BACKUP_DIR"
  ts=$(date +%Y%m%d-%H%M%S)
  dir="$BACKUP_DIR/$ts"
  mkdir -p "$dir" || return 1
  chmod 700 "$dir"

  if [ -L /etc/resolv.conf ]; then
    readlink -f /etc/resolv.conf > "$dir/resolv.conf.symlink" 2>/dev/null
    cp -L /etc/resolv.conf "$dir/resolv.conf" 2>/dev/null || cp /etc/resolv.conf "$dir/resolv.conf" 2>/dev/null
  elif [ -e /etc/resolv.conf ]; then
    cp -a /etc/resolv.conf "$dir/resolv.conf" 2>/dev/null
  fi

  {
    echo "timestamp=$ts"
    echo "dns_servers=$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')"
  } > "$dir/metadata.txt"

  log "[备份] 已备份到 $dir"
  # 只保留最近 20 份备份
  ls -1d "$BACKUP_DIR"/2* 2>/dev/null | sort | head -n -20 | while read -r old; do
    rm -rf "$old"
  done
  return 0
}

# ============================================================
# 接管系统 DNS（精简自 akdns.sh safe_write_resolv_conf + force_static_resolv_conf）
# Alpine 无 systemd-resolved/NetworkManager，直接写静态 /etc/resolv.conf
# ============================================================
apply_dns() {
  dns_ip="$1"

  # 若已锁定先解锁
  if command -v chattr >/dev/null 2>&1 && [ -e /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
    chattr -i /etc/resolv.conf 2>/dev/null || true
  fi

  # resolv.conf 是指向运行态文件的 symlink 时删除（udhcpc/dhcpcd 场景）
  if [ -L /etc/resolv.conf ]; then
    rm -f /etc/resolv.conf || { log "[应用] 删除 resolv.conf 符号链接失败"; return 1; }
  fi

  # 原子写入：先写临时文件再 mv
  tmp=$(mktemp /etc/resolv.conf.nfdns.XXXXXX) || { log "[应用] 创建临时文件失败"; return 1; }
  # 保留原有非 nameserver 配置行
  grep -vE '^nameserver|^options use-vc' /etc/resolv.conf > "$tmp" 2>/dev/null || true
  echo "nameserver $dns_ip" >> "$tmp"
  if [ "$DNS_USE_TCP" = "1" ]; then
    echo "options use-vc" >> "$tmp"
  fi
  chmod 644 "$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" /etc/resolv.conf || { rm -f "$tmp"; log "[应用] 写入 /etc/resolv.conf 失败"; return 1; }

  # 锁定，杜绝 dhcp 续租时覆盖
  if [ "$LOCK_RESOLV_CONF" = "1" ] && command -v chattr >/dev/null 2>&1; then
    if chattr +i /etc/resolv.conf 2>/dev/null; then
      log "[应用] 已锁定 /etc/resolv.conf（restore 时会自动解锁）"
    fi
  fi

  if ! grep -q "^nameserver $dns_ip" /etc/resolv.conf 2>/dev/null; then
    log "[应用] 验证失败: resolv.conf 中未找到 nameserver $dns_ip"
    return 1
  fi

  log "[应用] 系统 DNS 已切换为 $dns_ip"
  return 0
}

# ============================================================
# 验证系统解析（移植自 akdns.sh verify_system_dns）
# musl 无 getent，用 dig（不指定 @server，走 resolv.conf）验证
# ============================================================
verify_dns() {
  sleep 1
  if [ "$DNS_USE_TCP" = "1" ]; then
    # musl 忽略 use-vc，用 dig +tcp 显式验证 TCP 链路
    if dig +tcp +time=3 +tries=1 "$DOMAIN" >/dev/null 2>&1; then
      log "[验证] DNS 解析正常 (TCP)"
      return 0
    fi
  else
    if dig +time=3 +tries=1 "$DOMAIN" >/dev/null 2>&1; then
      log "[验证] DNS 解析正常"
      return 0
    fi
  fi
  log "[验证] DNS 解析验证失败（可能仍生效，或网络异常）"
  return 1
}

# ============================================================
# 还原（对应 akdns.sh 菜单「还原 DNS 配置」，取最近一次备份）
# ============================================================
restore_dns() {
  latest=$(ls -1d "$BACKUP_DIR"/2* 2>/dev/null | sort | tail -n1)
  if [ -z "$latest" ] || [ ! -f "$latest/resolv.conf" ]; then
    log "[还原] 没有找到可用备份"
    return 1
  fi
  if command -v chattr >/dev/null 2>&1 && [ -e /etc/resolv.conf ] && [ ! -L /etc/resolv.conf ]; then
    chattr -i /etc/resolv.conf 2>/dev/null || true
  fi
  rm -f /etc/resolv.conf
  cp -a "$latest/resolv.conf" /etc/resolv.conf || { log "[还原] 恢复文件失败"; return 1; }
  chmod 644 /etc/resolv.conf
  log "[还原] 已从 $latest 还原 /etc/resolv.conf"
  return 0
}

# ============================================================
# 主流程
# ============================================================
run_once() {
  force="$1"

  # 防 cron 任务重叠执行
  exec 9>"$LOCK_FILE" 2>/dev/null || true
  if command -v flock >/dev/null 2>&1; then
    flock -n 9 || { log "[守护] 上一次任务仍在运行，跳过本次"; exit 0; }
  fi

  need_cmd curl curl || exit 1
  need_cmd dig bind-tools || exit 1

  if [ "$force" = "0" ] && check_netflix; then
    exit 0
  fi

  if [ "$force" = "1" ]; then
    log "[流程] 强制模式：跳过 Netflix 检测，直接测速切换"
  else
    log "[流程] Netflix 未解锁，开始 DNS 测速并切换..."
  fi

  find_best_dns || { log "[流程] 无可达 AKDNS 节点，本次放弃"; exit 1; }
  backup_resolv || log "[流程] 备份失败，继续尝试切换"
  apply_dns "$BEST_DNS" || { log "[流程] 切换 DNS 失败"; exit 1; }

  # 验证不通过则自动回滚，避免留下不可用的 resolv.conf
  if ! verify_dns; then
    log "[流程] 切换后解析异常，自动还原原 DNS 配置"
    restore_dns
    exit 1
  fi

  # 切换后复测 Netflix
  sleep 2
  if check_netflix; then
    log "[流程] 切换成功，Netflix 已解锁 ✓"
  else
    log "[流程] 切换后 Netflix 仍未解锁，请到控制台为本机 IP 勾选解锁服务: $CONSOLE_URL"
    exit 2
  fi
}

show_status() {
  echo "当前 /etc/resolv.conf:"
  grep -E '^nameserver|^options' /etc/resolv.conf 2>/dev/null || echo "  (空或不存在)"
  if command -v lsattr >/dev/null 2>&1 && [ -e /etc/resolv.conf ]; then
    attrs=$(lsattr /etc/resolv.conf 2>/dev/null | awk '{print $1}')
    case "$attrs" in *i*) echo "  状态: 已锁定 (immutable)" ;; *) echo "  状态: 未锁定" ;; esac
  fi
  echo ""
  echo "测速节点 (共 $(echo $DNS_LIST | wc -w) 个):"
  for d in $DNS_LIST; do echo "  $d"; done
  if [ -n "${DNS_LIST_URL:-}" ]; then
    echo "  来源: 远程 $DNS_LIST_URL"
  elif [ -f "$CONF_FILE" ]; then
    echo "  来源: 配置文件 $CONF_FILE"
  else
    echo "  来源: 内置默认列表"
  fi
  echo ""
  check_netflix || true
  echo ""
  echo "定时任务:"
  crontab -l 2>/dev/null | grep -F "$0" || echo "  (未安装)"
  echo "日志: $LOG_FILE"
}

install_cron() {
  interval="${1:-5}"
  case "$interval" in
    ''|*[!0-9]*) echo "用法: $0 install-cron [分钟数(1-59)]"; exit 1 ;;
  esac
  if [ "$interval" -lt 1 ] || [ "$interval" -gt 59 ]; then
    echo "间隔需在 1-59 分钟之间"; exit 1
  fi
  self=$(readlink -f "$0" 2>/dev/null || echo "$0")
  tmp=$(mktemp) || exit 1
  # 先清掉旧的同类任务（按脚本路径匹配）
  crontab -l 2>/dev/null | grep -vF "$self run" > "$tmp" || true
  # 字段间用单个空格分隔，行尾不加注释，避免 crond 解析歧义
  echo "*/$interval * * * * $self run" >> "$tmp"
  if ! crontab "$tmp"; then
    rm -f "$tmp"
    echo "写入 crontab 失败"
    exit 1
  fi
  rm -f "$tmp"

  # Alpine: 确保 crond 开机自启并运行
  rc-update add crond default >/dev/null 2>&1 || true
  rc-service crond start >/dev/null 2>&1 || rc-service crond restart >/dev/null 2>&1 || true

  # 回读校验：字段必须是 5 段，且第一段形如 */N
  line=$(crontab -l 2>/dev/null | grep -F "$self run" | tail -n1)
  fields=$(echo "$line" | awk '{print NF}')
  echo ""
  echo "已安装定时任务（每 $interval 分钟）："
  echo "  $line"
  if [ "${fields:-0}" -lt 6 ]; then
    echo ""
    echo "警告: 该行字段数异常（$fields），请用 'crontab -l | cat -A' 检查空格"
  fi
  echo ""
  echo "crond 状态: $(rc-service crond status 2>&1 | head -1)"
}

uninstall_cron() {
  self=$(readlink -f "$0" 2>/dev/null || echo "$0")
  tmp=$(mktemp) || exit 1
  crontab -l 2>/dev/null | grep -vF "$self run" > "$tmp"
  crontab "$tmp" && rm -f "$tmp"
  echo "已移除定时任务"
}

usage() {
  sed -n '2,30p' "$0"
}

# 只测速，不修改任何系统配置（用于排障/验证测速逻辑）
test_speed() {
  need_cmd dig bind-tools || exit 1
  find_best_dns || { log "[测速] 无可用节点"; exit 1; }
  echo ""
  echo "最优节点: $BEST_DNS$( [ "$DNS_USE_TCP" = "1" ] && echo " (TCP)" )"
  echo "（仅测速，未修改 /etc/resolv.conf）"
}

# ============================================================
case "${1:-run}" in
  run)            run_once 0 ;;
  force)          run_once 1 ;;
  test-speed)     test_speed ;;
  restore)        restore_dns ;;
  status)         show_status ;;
  install-cron)   install_cron "${2:-5}" ;;
  uninstall-cron) uninstall_cron ;;
  -h|--help|help) usage ;;
  *) echo "未知命令: $1"; usage; exit 1 ;;
esac
