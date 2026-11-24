#!/bin/sh
# ============================================================
# nf-dns-watch.sh v1.0 - Netflix 解锁守护 + AKDNS 自动切换
# 适用于 Alpine 3.21（BusyBox ash / OpenRC / musl libc）
#
# 目标：以「Netflix 能解锁」为第一优先，延迟只作为同条件下的择优依据。
# 测速与切换逻辑整理自 akdns.sh v3.0.0（菜单 4「一键测速并应用」）：
#   检测 Netflix 是否解锁
#     ├─ 已解锁 → 记录日志，退出
#     └─ 未解锁 → dig 并行测速所有 AKDNS 节点（UDP，全超时自动回退 TCP）
#                 → 按延迟升序排序
#                 → 依次切换候选节点并实测解锁：
#                     切换 → 验证解析 → 复测 Netflix
#                     能解锁即停（此时也一定是能解锁的节点里最快的）
#                     不能解锁 → 试下一个
#                 → 全部失败则还原原始 DNS 并提示控制台配置
#
# 依赖（Alpine 3.21）:
#   apk add curl bind-tools
#
# 用法:
#   nf-dns-watch.sh run              检测一次（cron 调用入口）
#   nf-dns-watch.sh force            无论 Netflix 状态都强制测速并换 DNS
#   nf-dns-watch.sh test-speed       只测速看结果，不改任何系统配置
#   nf-dns-watch.sh diag             诊断：区分「节点不可达」与「AKDNS 未下发解锁」
#   nf-dns-watch.sh test-notify      发送一条测试通知，验证推送配置
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
RESTORE_ON_ALL_FAIL=1            # 所有节点都无法解锁时，还原原始 DNS（0=保留最后测试的节点）

# ---- 通知（Bark）----
# 留空 = 不发送通知。请在 /etc/nf-dns-watch.conf 中配置，避免把 key 提交到公开仓库。
# 格式示例：https://your-bark-host/YOUR_KEY/title/body?group=example&ttl=600
NOTIFY_URL=""
NOTIFY_ENABLED=1
NOTIFY_REPEAT_INTERVAL=18000     # 持续失败时的重复通知间隔（秒），默认 5 小时
STATE_FILE="/var/lib/nf-dns-watch/state"

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
#   NOTIFY_URL="https://your-bark-host/YOUR_KEY/title/body?group=example&ttl=600"
#   NOTIFY_REPEAT_INTERVAL=18000                        # 失败重复通知间隔（秒）
# 注意：NOTIFY_URL 含推送密钥，务必只写在配置文件里（chmod 600），不要提交到仓库。
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
# 通知（Bark 兼容接口）
# 支持两种地址写法：
#   1) https://host/KEY/title/body?group=xx&ttl=600   （GET 风格，自动转成 POST JSON）
#   2) https://host/KEY                              （直接 POST JSON）
# 用 POST JSON 而非拼路径，避免中文标题需要 URL 编码的问题
# ============================================================
send_notify() {
  n_title="$1"
  n_body="$2"

  [ "$NOTIFY_ENABLED" = "1" ] || return 0
  [ -n "${NOTIFY_URL:-}" ] || { log "[通知] 未配置 NOTIFY_URL，跳过"; return 0; }
  need_cmd curl curl || return 0

  # 去掉 /title/body 及其后的查询串，得到 Bark 的 KEY 端点
  n_base=$(printf '%s' "$NOTIFY_URL" | sed 's#/title/body.*##')
  n_group=$(printf '%s' "$NOTIFY_URL" | sed -n 's/.*[?&]group=\([^&]*\).*/\1/p')
  n_ttl=$(printf '%s' "$NOTIFY_URL" | sed -n 's/.*[?&]ttl=\([0-9]*\).*/\1/p')
  [ -n "$n_group" ] || n_group="nf-dns-watch"
  [ -n "$n_ttl" ] || n_ttl=600

  n_payload=$(printf '{"title":"%s","body":"%s","group":"%s","ttl":%s}' "$n_title" "$n_body" "$n_group" "$n_ttl")

  n_resp=$(curl -s -X POST "$n_base" -H 'Content-Type: application/json; charset=utf-8' -d "$n_payload" --connect-timeout 8 --max-time 15 2>/dev/null)

  case "$n_resp" in
    *'"code":200'*|*'"code": 200'*)
      log "[通知] 已发送: $n_title"
      ;;
    *)
      log "[通知] 发送失败: ${n_resp:-无响应}"
      ;;
  esac
  return 0
}

# ============================================================
# 状态记忆：避免重复通知
# 文件内容：STATE_STATUS=ok|fail / STATE_LAST_NOTIFY=<epoch>
# ============================================================
read_state() {
  STATE_STATUS="ok"
  STATE_LAST_NOTIFY=0
  if [ -f "$STATE_FILE" ]; then
    # shellcheck source=/dev/null
    . "$STATE_FILE" 2>/dev/null || true
  fi
  STATE_STATUS="${STATE_STATUS:-ok}"
  STATE_LAST_NOTIFY="${STATE_LAST_NOTIFY:-0}"
}

save_state() {
  mkdir -p "$(dirname "$STATE_FILE")" 2>/dev/null || true
  printf 'STATE_STATUS=%s\nSTATE_LAST_NOTIFY=%s\n' "$1" "${2:-0}" > "$STATE_FILE" 2>/dev/null || true
}

# 失败通知（带去重）：
#   · 首次失败 → 立即通知
#   · 持续失败 → 每 NOTIFY_REPEAT_INTERVAL（默认 5 小时）才再通知一次
#   · 恢复正常 → 由调用方发一次"已恢复"，并把状态复位
notify_all_fail() {
  reason="$1"
  now=$(date +%s)

  if [ "$STATE_STATUS" != "fail" ]; then
    send_notify "Netflix 解锁失败" "$reason。已还原原始 DNS，请到控制台检查解锁配置"
    save_state fail "$now"
    return 0
  fi

  elapsed=$((now - STATE_LAST_NOTIFY))
  if [ "$elapsed" -ge "$NOTIFY_REPEAT_INTERVAL" ]; then
    hours=$((elapsed / 3600))
    send_notify "Netflix 仍未解锁" "$reason。已持续约 ${hours} 小时未解锁，请尽快处理"
    save_state fail "$now"
  else
    log "[通知] 仍处于失败状态，距上次通知 $((elapsed / 60)) 分钟，未满 $((NOTIFY_REPEAT_INTERVAL / 3600)) 小时，本次不重复通知"
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

# 测速并按延迟升序排序，结果写入 $1（每行 "平均耗时 IP"）
# 注意：在调用者 shell 内执行（不放进命令替换），DNS_USE_TCP 才能生效
rank_dns() {
  out_file="$1"
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

  printf '%s\n' "$result" > "$out_file"
  [ -n "$result" ] || return 1
  best_avg=$(head -n1 "$out_file" | awk '{print $1}')
  [ "${best_avg:-1000}" -lt 1000 ] || return 1
  return 0
}

# 打印排序结果
print_ranking() {
  while read -r avg dns; do
    [ -n "$dns" ] || continue
    if [ "$avg" -ge 1000 ]; then
      log "[测速]   $dns  超时"
    else
      log "[测速]   $dns  ${avg}ms"
    fi
  done < "$1"
}

# 测速选最优（仅 test-speed 命令使用；run 流程用 rank_dns + 逐个解锁测试）
find_best_dns() {
  need_cmd dig bind-tools || return 1
  load_dns_list
  BEST_DNS=""
  f=$(mktemp) || return 1
  if ! rank_dns "$f"; then
    print_ranking "$f"
    rm -f "$f"
    log "[测速] 所有 AKDNS 节点 UDP/TCP 均超时"
    return 1
  fi
  print_ranking "$f"
  BEST_DNS=$(head -n1 "$f" | awk '{print $2}')
  best_avg=$(head -n1 "$f" | awk '{print $1}')
  rm -f "$f"
  log "[测速] 延迟最低节点: $BEST_DNS (${best_avg}ms$( [ "$DNS_USE_TCP" = "1" ] && echo ", TCP" ))"
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
  if verify_dns_quick; then
    log "[验证] DNS 解析正常$( [ "$DNS_USE_TCP" = "1" ] && echo " (TCP)" )"
    return 0
  fi
  log "[验证] DNS 解析验证失败（可能仍生效，或网络异常）"
  return 1
}

# 静默版验证：逐个候选测试时使用，避免刷屏
verify_dns_quick() {
  if [ "$DNS_USE_TCP" = "1" ]; then
    # musl 忽略 use-vc，用 dig +tcp 显式验证 TCP 链路
    dig +tcp +time=3 +tries=1 "$DOMAIN" >/dev/null 2>&1
  else
    dig +time=3 +tries=1 "$DOMAIN" >/dev/null 2>&1
  fi
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

  read_state

  # 分支一：当前已解锁
  if [ "$force" = "0" ] && check_netflix; then
    if [ "$STATE_STATUS" = "fail" ]; then
      cur_dns=$(grep -E '^nameserver' /etc/resolv.conf 2>/dev/null | awk '{print $2}' | tr '\n' ' ')
      log "[通知] 状态由失败恢复正常"
      send_notify "Netflix 解锁已恢复" "解锁已恢复，当前 DNS: ${cur_dns:-未知}"
      save_state ok 0
    fi
    exit 0
  fi

  if [ "$force" = "1" ]; then
    log "[流程] 强制模式：跳过 Netflix 检测，直接进入节点解锁测试"
  else
    log "[流程] Netflix 未解锁，按延迟顺序逐个测试节点能否解锁"
  fi

  load_dns_list
  rank_file=$(mktemp) || exit 1
  if ! rank_dns "$rank_file"; then
    print_ranking "$rank_file"
    rm -f "$rank_file"
    log "[流程] 所有节点不可达，本次放弃"
    notify_all_fail "所有 AKDNS 节点均不可达（测速全部超时），无法切换 DNS"
    exit 1
  fi
  print_ranking "$rank_file"

  # 只备份一次，记录真正的原始配置，供全部失败时回滚
  backup_resolv || log "[流程] 备份失败，继续尝试"

  tried=0
  applied=""
  while read -r avg dns; do
    [ -n "$dns" ] || continue
    if [ "$avg" -ge 1000 ]; then
      log "[切换] $dns 不可达，跳过"
      continue
    fi
    tried=$((tried + 1))
    log "[切换] 候选 $tried: $dns (${avg}ms) 正在测试解锁..."
    if ! apply_dns "$dns"; then
      log "[切换] $dns 写入失败，跳过"
      continue
    fi
    if ! verify_dns_quick; then
      log "[切换] $dns 解析异常，跳过"
      continue
    fi
    if check_netflix; then
      applied="$dns"
      break
    fi
    log "[切换] $dns 无法解锁，继续下一个"
  done < "$rank_file"
  rm -f "$rank_file"

  if [ -n "$applied" ]; then
    log "[完成] 已切换到 $applied，Netflix 解锁成功 ✓"
    if [ "$STATE_STATUS" = "fail" ]; then
      log "[通知] 状态由失败恢复正常"
      send_notify "Netflix 解锁已恢复" "已切换到 $applied，Netflix 解锁恢复"
    fi
    save_state ok 0
    exit 0
  fi

  # 所有候选都无法解锁
  if [ "$RESTORE_ON_ALL_FAIL" = "1" ]; then
    log "[完成] 所有节点均无法解锁，还原原始 DNS 配置"
    restore_dns
  else
    log "[完成] 所有节点均无法解锁，保留最后测试的节点"
  fi
  log "[提示] 请到控制台为本机 IP 勾选解锁服务: $CONSOLE_URL"
  notify_all_fail "已测试全部 $(echo "$DNS_LIST" | wc -w) 个节点，均无法解锁 Netflix"
  exit 2
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
  read_state
  if [ -n "${NOTIFY_URL:-}" ]; then
    masked=$(printf '%s' "$NOTIFY_URL" | sed 's#\(/[^/]\{4\}\)[^/]*#\1***#')
    echo "通知: 已启用 ($masked)"
    if [ "$STATE_LAST_NOTIFY" -gt 0 ]; then
      echo "  状态记忆: $STATE_STATUS (上次通知于 $(( ($(date +%s) - STATE_LAST_NOTIFY) / 60 )) 分钟前)"
    else
      echo "  状态记忆: $STATE_STATUS (尚未发送过通知)"
    fi
    echo "  失败重复间隔: $((NOTIFY_REPEAT_INTERVAL / 3600)) 小时"
  else
    echo "通知: 未配置（在 $CONF_FILE 中设置 NOTIFY_URL）"
  fi
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

  # 改动前先备份现有 crontab，避免误伤系统自带任务
  mkdir -p /var/lib/nf-dns-watch 2>/dev/null || true
  old_count=0
  if crontab -l > /var/lib/nf-dns-watch/crontab.bak 2>/dev/null; then
    old_count=$(grep -c . /var/lib/nf-dns-watch/crontab.bak 2>/dev/null || echo 0)
    echo "已备份原 crontab 到 /var/lib/nf-dns-watch/crontab.bak（$old_count 行）"
  fi

  tmp=$(mktemp) || exit 1
  # 先清掉旧的同类任务（按脚本路径匹配），其余任务原样保留
  crontab -l 2>/dev/null | grep -vF "$self run" > "$tmp" || true
  # 用 printf 而非 echo，字段间单个空格，行尾不加注释
  printf '*/%s * * * * %s run\n' "$interval" "$self" >> "$tmp"

  new_count=$(grep -c . "$tmp" 2>/dev/null || echo 0)
  if [ "$new_count" -lt "$old_count" ]; then
    echo "警告: 新 crontab 行数($new_count) 少于原行数($old_count)，原文件已备份"
    echo "      如确认无误可继续，否则执行: crontab /var/lib/nf-dns-watch/crontab.bak"
  fi

  if ! crontab "$tmp"; then
    rm -f "$tmp"
    echo "写入 crontab 失败，原文件仍保留在 /var/lib/nf-dns-watch/crontab.bak"
    exit 1
  fi
  rm -f "$tmp"

  # Alpine: 确保 crond 开机自启并运行
  rc-update add crond default >/dev/null 2>&1 || true
  rc-service crond start >/dev/null 2>&1 || rc-service crond restart >/dev/null 2>&1 || true

  # 回读校验：必须 6 段以上，且第一段严格等于 */N
  line=$(crontab -l 2>/dev/null | grep -F "$self run" | tail -n1)
  fields=$(echo "$line" | awk '{print NF}')
  first=$(echo "$line" | awk '{print $1}')
  echo ""
  echo "已安装定时任务（每 $interval 分钟）："
  echo "  $line"
  if [ "${fields:-0}" -lt 6 ] || [ "$first" != "*/$interval" ]; then
    echo ""
    echo "警告: cron 行格式异常（字段数=$fields, 首段=[$first]，期望 [*/$interval]）"
    echo "      请执行 'crontab -l | cat -A' 检查空格是否丢失"
  fi
  echo ""
  echo "crond 状态: $(rc-service crond status 2>&1 | head -1)"
}

uninstall_cron() {
  self=$(readlink -f "$0" 2>/dev/null || echo "$0")
  mkdir -p /var/lib/nf-dns-watch 2>/dev/null || true
  crontab -l > /var/lib/nf-dns-watch/crontab.bak 2>/dev/null || true
  tmp=$(mktemp) || exit 1
  crontab -l 2>/dev/null | grep -vF "$self run" > "$tmp" || true
  crontab "$tmp" && rm -f "$tmp"
  echo "已移除定时任务（原文件备份在 /var/lib/nf-dns-watch/crontab.bak）"
}

usage() {
  sed -n '2,31p' "$0"
}

# 只测速，不修改任何系统配置（用于排障/验证测速逻辑）
test_speed() {
  need_cmd dig bind-tools || exit 1
  find_best_dns || { log "[测速] 无可用节点"; exit 1; }
  echo ""
  echo "最优节点: $BEST_DNS$( [ "$DNS_USE_TCP" = "1" ] && echo " (TCP)" )"
  echo "（仅测速，未修改 /etc/resolv.conf）"
}

# 诊断：判断「节点不可达」还是「AKDNS 没给本机 IP 下发解锁」
# 原理：AKDNS 的解锁是靠改写 Netflix 域名的解析结果实现的。
#       若节点返回的 A 记录与公共 DNS 完全一致，说明没有下发解锁（白名单/IP 问题），
#       而不是节点列表变了或节点挂了。
diag() {
  need_cmd dig bind-tools || exit 1

  echo "=== 出口公网 IPv4 ==="
  pub=$(curl -4 -s --connect-timeout 5 --max-time 10 https://api.ip.sb/ip 2>/dev/null | tr -d ' \r\n')
  if [ -z "$pub" ]; then
    pub=$(curl -4 -s --connect-timeout 5 --max-time 10 https://ipinfo.io/ip 2>/dev/null | tr -d ' \r\n')
  fi
  echo "  ${pub:-获取失败（不影响下面的判断）}"
  echo "  ↑ AKDNS 控制台里要绑定的就是这个 IP"
  echo ""

  echo "=== 对照解析（公共 DNS 8.8.8.8）==="
  base=$(dig +short +time=3 +tries=1 @8.8.8.8 www.netflix.com A 2>/dev/null | grep -E '^[0-9]+\.' | sort | tr '\n' ' ')
  echo "  www.netflix.com -> ${base:-查询失败}"
  echo ""

  echo "=== 各节点对 www.netflix.com 的解析 ==="
  load_dns_list
  hit=0
  alive=0
  unlock_ip=""
  unlock_dns=""
  for dns in $DNS_LIST; do
    ans=$(dig +short +time=2 +tries=1 "@$dns" www.netflix.com A 2>/dev/null | grep -E '^[0-9]+\.' | sort | tr '\n' ' ')
    if [ -z "$ans" ]; then
      printf '  %-16s %s\n' "$dns" "无响应 / 不可达"
    else
      alive=$((alive + 1))
      if [ -n "$base" ] && [ "$ans" = "$base" ]; then
        printf '  %-16s %-30s %s\n' "$dns" "$ans" "未下发解锁"
      else
        hit=$((hit + 1))
        printf '  %-16s %-30s %s\n' "$dns" "$ans" "解锁已生效"
        if [ -z "$unlock_ip" ]; then
          unlock_ip=$(printf '%s' "$ans" | awk '{print $1}')
          unlock_dns="$dns"
        fi
      fi
    fi
  done
  echo ""

  echo "=== 判定 ==="
  if [ "$alive" -eq 0 ]; then
    echo "  所有节点都不可达：本机到 AKDNS 的网络被拦，或 UDP/53 被墙（脚本会自动回退 TCP）"
  elif [ "$hit" -eq 0 ]; then
    echo "  节点都活着，但没有任何节点给本机 IP 下发解锁。"
    echo "  说明问题在 AKDNS 侧，不是脚本里的节点列表："
    echo "   1) 本机出口 IP 未加入白名单（或换过 IP / 重装过系统）→ $CONSOLE_URL"
    echo "   2) 白名单刚加，生效约需 1-2 小时"
    echo "   3) 账号套餐/解锁服务已变更或到期"
  else
    echo "  有 $hit 个节点已下发解锁，脚本会自动切到这些节点上。"
  fi
  echo ""

  # 关键一步：能解析到解锁入口，不代表能真正访问 Netflix
  # 这里用 --resolve 直接把域名钉到解锁入口 IP 上实测，不改动系统 DNS
  if [ -z "$unlock_ip" ]; then
    return 0
  fi
  echo "=== 解锁入口实测（不修改系统 DNS）==="
  echo "  入口: $unlock_dns -> $unlock_ip"
  p1=""
  p2=""
  for t in 81280792 70143836; do
    r=$(curl -4 -sL -A "$NF_UA" -o /dev/null -w '%{http_code}|%{url_effective}' --resolve "www.netflix.com:443:$unlock_ip" --connect-timeout 8 --max-time 25 "https://www.netflix.com/title/$t" 2>/dev/null)
    code=${r%%|*}
    final=${r#*|}
    [ -n "$code" ] || code=000
    printf '  title %-9s HTTP %-4s %s\n' "$t" "$code" "$final"
    if [ "$t" = "81280792" ]; then p1=$code; else p2=$code; fi
  done
  echo ""
  echo "=== 实测结论 ==="
  if [ "$p1" = "200" ] && [ "$p2" = "200" ]; then
    echo "  两个标题都是 200，解锁正常。若脚本仍报未解锁，请检查脚本里的 NF_UA 是否被改、或本机 IPv6 抢先解析（试试禁用 v6）"
  elif [ "$p1" = "200" ] && [ "$p2" = "404" ]; then
    echo "  非自制剧 200 / 自制剧 404 → 仅自制剧，按判定视为未解锁"
  elif [ "$p1" = "404" ] && [ "$p2" = "200" ]; then
    echo "  非自制剧 404 / 自制剧 200 → 解锁区域里没有该非自制剧（常见于港区），属正常，"
    echo "  但按标准判定会被算作「未解锁」，脚本会一直重试。见下方说明。"
  elif [ "$p1" = "403" ] || [ "$p2" = "403" ]; then
    echo "  被封锁（403）：入口 IP 在，但区域策略拒绝"
  elif [ "$p1" = "000" ] || [ "$p2" = "000" ]; then
    echo "  连不上解锁入口（000）：入口 IP 不可达，或 TLS 握手被重置"
    echo "  试试: curl -v --resolve www.netflix.com:443:$unlock_ip https://www.netflix.com/ 看卡在哪一步"
  else
    echo "  非 200 响应，见上方状态码"
  fi
}

# 测试通知通道是否可用
test_notify() {
  if [ -z "${NOTIFY_URL:-}" ]; then
    echo "未配置 NOTIFY_URL，请在 $CONF_FILE 中设置，例如："
    echo 'NOTIFY_URL="https://your-bark-host/YOUR_KEY/title/body?group=example&ttl=600"'
    exit 1
  fi
  echo "正在向通知接口发送测试消息..."
  send_notify "nf-dns-watch 测试" "如果你收到这条消息，说明通知配置正确"
}

# ============================================================
case "${1:-run}" in
  run)            run_once 0 ;;
  force)          run_once 1 ;;
  test-speed)     test_speed ;;
  diag)           diag ;;
  test-notify|notify-test) test_notify ;;
  restore)        restore_dns ;;
  status)         show_status ;;
  install-cron)   install_cron "${2:-5}" ;;
  uninstall-cron) uninstall_cron ;;
  -h|--help|help) usage ;;
  *) echo "未知命令: $1"; usage; exit 1 ;;
esac
