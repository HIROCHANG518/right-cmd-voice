#!/usr/bin/env bash
#
# right-cmd-voice · 一键安装
#
# 用法一（推荐，可先审阅）：
#   git clone https://github.com/HIROCHANG518/right-cmd-voice.git
#   cd right-cmd-voice && ./install.sh
#
# 用法二（一条命令）：
#   curl -fsSL https://raw.githubusercontent.com/HIROCHANG518/right-cmd-voice/main/install.sh | bash
#
# 参数：
#   --key <f18|f13|f14|f15|fnspace>  单击时输出的键，默认 f18；fnspace = 发 Fn+Space（匹配微信输入法默认）
#   --action <voice|switch>       voice = 给输入法绑语音输入（默认）；switch = 直接切输入法
#   --dry-run                     只打印将要做什么，不落盘
#   -h, --help
#
# 做的事：装 Karabiner-Elements → 写规则并预启用 → 唤起导入 → 权限值守。
# 不做的事：TCC 授权弹窗里的「允许」、驱动扩展开关、输入法里录制快捷键
#           —— macOS 安全模型不允许脚本代劳，脚本只负责打开正确的页面并轮询。
set -euo pipefail

KEY="f18"
ACTION="voice"
DRY_RUN=0
RULES_DIR="$HOME/.config/karabiner/assets/complex_modifications"
RULE_FILE="$RULES_DIR/right_cmd_voice.json"
KARABINER_CFG="$HOME/.config/karabiner/karabiner.json"
KARABINER_APP="/Applications/Karabiner-Elements.app"

usage() {
  cat <<'EOF'
right-cmd-voice · 一键安装

用法：
  git clone https://github.com/HIROCHANG518/right-cmd-voice.git
  cd right-cmd-voice && ./install.sh

  curl -fsSL https://raw.githubusercontent.com/HIROCHANG518/right-cmd-voice/main/install.sh | bash

参数：
  --key <f18|f13|fnspace>  单击时输出的键，默认 f18；fnspace = 发 Fn+Space（微信输入法默认语音键）
  --action <voice|switch> voice = 给输入法绑语音输入（默认）；switch = 直接切输入法
  --dry-run               只打印将要做什么，不落盘
  -h, --help
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    --key)
      [ $# -ge 2 ] || { echo "✗ --key 缺少参数"; exit 1; }
      KEY="$2"; shift 2 ;;
    --action)
      [ $# -ge 2 ] || { echo "✗ --action 缺少参数"; exit 1; }
      ACTION="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "✗ 未知参数: $1"; echo; usage; exit 1 ;;
  esac
done

case "$ACTION" in
  voice|switch) ;;
  *) echo "✗ --action 只能是 voice 或 switch"; exit 1 ;;
esac

if [ "$(uname -s)" != "Darwin" ]; then
  echo "✗ 本项目只支持 macOS"
  exit 1
fi

say() { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------- 生成规则 JSON
build_rule() {
  python3 - "$KEY" "$ACTION" <<'PY'
import json, sys

key, action = sys.argv[1], sys.argv[2]

if action == "switch":
    alone = [{"key_code": "spacebar", "modifiers": ["left_control"]}]
    title = "右Command单按切换输入法（⌃Space）"
    desc = "Right Command alone → ⌃Space（组合键仍是 Command）"
elif key == "fnspace":
    # 微信输入法语音输入默认快捷键就是 Fn+Space，走这档不用改输入法配置
    alone = [{"key_code": "spacebar", "modifiers": ["fn"]}]
    title = "右Command单按触发语音输入（Fn+Space）"
    desc = "Right Command alone → Fn+Space（组合键仍是 Command）"
else:
    alone = [{"key_code": key}]
    title = "右Command单按触发语音输入（%s）" % key.upper()
    desc = "Right Command alone → %s（组合键仍是 Command）" % key.upper()

rule = {
    "title": title,
    "rules": [
        {
            "description": desc,
            "manipulators": [
                {
                    "type": "basic",
                    "from": {
                        "key_code": "right_command",
                        "modifiers": {"optional": ["any"]},
                    },
                    "to": [{"key_code": "right_command", "lazy": True}],
                    "to_if_alone": alone,
                }
            ],
        }
    ],
}

sys.stdout.write(json.dumps(rule, ensure_ascii=False, indent=2) + "\n")
PY
}

# ---------------------------------------------------------------- 1. Homebrew
ensure_brew() {
  if command -v brew >/dev/null 2>&1; then
    return 0
  fi
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    if [ -x "$p" ]; then
      eval "$("$p" shellenv)"
      return 0
    fi
  done

  step "未检测到 Homebrew，正在安装（会要求输入密码）"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "    [dry-run] 安装 Homebrew"
    return 0
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || {
    say "✗ Homebrew 安装失败。请手动安装后重跑：https://brew.sh"
    exit 1
  }
  for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$p" ] && eval "$("$p" shellenv)" && break
  done
}

# ---------------------------------------------------------------- 2. Karabiner
ensure_karabiner() {
  step "1/6 检查 Karabiner-Elements"
  if [ -d "$KARABINER_APP" ]; then
    say "    ✓ 已安装，跳过"
    return 0
  fi
  say "    未安装，开始安装 cask（会要求输入密码）"
  ensure_brew
  run brew install --cask karabiner-elements
}

# ---------------------------------------------------------------- 3. 最小配置兜底
ensure_minimal_config() {
  step "4/6 检查 karabiner.json"
  if [ -f "$KARABINER_CFG" ]; then
    say "    ✓ 已有配置，不动它"
    return 0
  fi
  say "    没有配置文件，唤起 Karabiner 让它自己生成"
  [ "$DRY_RUN" -eq 1 ] || open -a "Karabiner-Elements" 2>/dev/null || true
  i=0
  while [ $i -lt 20 ] && [ ! -f "$KARABINER_CFG" ]; do
    [ "$DRY_RUN" -eq 1 ] && break
    sleep 0.5
    i=$((i + 1))
  done
  if [ -f "$KARABINER_CFG" ]; then
    say "    ✓ 已生成"
    return 0
  fi
  say "    仍然没有，写入最小配置兜底"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "    [dry-run] 写最小 karabiner.json"
    return 0
  fi
  mkdir -p "$(dirname "$KARABINER_CFG")"
  cat > "$KARABINER_CFG" <<'JSON'
{
  "global": {
    "check_for_updates_on_startup": true,
    "show_in_menu_bar": true,
    "show_profile_name_in_menu_bar": false
  },
  "profiles": [
    {
      "name": "Default profile",
      "selected": true,
      "complex_modifications": {
        "rules": [],
        "parameters": {
          "basic.simultaneous_threshold_milliseconds": 50,
          "basic.to_if_alone_timeout_milliseconds": 1000,
          "basic.to_if_held_down_threshold_milliseconds": 500
        }
      },
      "devices": [],
      "fn_function_keys": [],
      "simple_modifications": [],
      "virtual_hid_keyboard": {
        "keyboard_type_v2": "apple-vendor"
      }
    }
  ]
}
JSON
  say "    ✓ 已写入"
}

# ---------------------------------------------------------------- 4. 写规则
install_rule() {
  step "2/6 写入规则文件"
  local tmp
  tmp="$(mktemp)"
  build_rule > "$tmp"
  python3 -m json.tool "$tmp" >/dev/null || { say "✗ 生成的规则 JSON 非法"; rm -f "$tmp"; exit 1; }

  if [ -f "$RULE_FILE" ] && cmp -s "$tmp" "$RULE_FILE"; then
    say "    ✓ 规则已是最新，跳过"
    rm -f "$tmp"
    return 0
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    say "    [dry-run] 写入 $RULE_FILE"
    rm -f "$tmp"
    return 0
  fi

  mkdir -p "$RULES_DIR"
  mv "$tmp" "$RULE_FILE"
  say "    ✓ 已写入 $RULE_FILE"
}

# ---------------------------------------------------------------- 5. 唤起导入
open_import() {
  step "6/6 唤起 Karabiner 导入"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "    [dry-run] 打开 karabiner:// 导入链接"
    return 0
  fi
  open -a "Karabiner-Elements" 2>/dev/null || true
  local enc
  enc="$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote('file://'+sys.argv[1], safe=''))" "$RULE_FILE")"
  open "karabiner://karabiner/assets/complex_modifications/import?url=$enc" 2>/dev/null || true
}

# ---------------------------------------------------------------- 6. 规则预启用（免手动 Add rule）
# karabiner.json 缺失 → 直接写入已启用规则的最小配置；
# 已存在 → 备份后合并规则（不碰其它配置）。
enable_rule_in_config() {
  step "3/6 把规则预启用进 karabiner.json"
  if [ ! -f "$KARABINER_CFG" ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
      say "    [dry-run] 写入含规则的 karabiner.json"
      return 0
    fi
    mkdir -p "$(dirname "$KARABINER_CFG")"
    python3 - "$KARABINER_CFG" "$RULE_FILE" <<'PY'
import json, sys
cfg_path, rule_path = sys.argv[1], sys.argv[2]
rule = json.load(open(rule_path))
cfg = {
    "global": {
        "check_for_updates_on_startup": True,
        "show_in_menu_bar": True,
        "show_profile_name_in_menu_bar": False,
        "unsafe_ui": False,
    },
    "profiles": [
        {
            "name": "Default",
            "selected": True,
            "complex_modifications": {
                "parameters": {
                    "basic.simultaneous_threshold_milliseconds": 50,
                    "basic.to_delayed_action_delay_milliseconds": 500,
                    "basic.to_if_alone_timeout_milliseconds": 1000,
                    "basic.to_if_held_down_threshold_milliseconds": 500,
                },
                "rules": rule["rules"],
            },
            "devices": [],
            "fn_function_keys": [],
            "simple_modifications": [],
            "virtual_hid_keyboard": {
                "country_code": 0,
                "indicate_sticky_modifier_keys": False,
            },
        }
    ],
}
json.dump(cfg, open(cfg_path, "w"), ensure_ascii=False, indent=4)
PY
    say "    ✓ 已写入并启用（无需手动 Add rule）"
    return 0
  fi

  # 已有配置：备份 + 合并
  if [ "$DRY_RUN" -eq 1 ]; then
    say "    [dry-run] 备份并合并规则到 karabiner.json"
    return 0
  fi
  local bak
  bak="$KARABINER_CFG.bak.$(date +%Y%m%d%H%M%S)"
  cp "$KARABINER_CFG" "$bak"
  python3 - "$KARABINER_CFG" "$RULE_FILE" "$bak" <<'PY'
import json, sys
cfg_path, rule_path, bak = sys.argv[1:4]
cfg = json.load(open(cfg_path))
rule = json.load(open(rule_path))
desc = rule["rules"][0]["description"]
changed = False
for p in cfg.get("profiles", []):
    if p.get("selected"):
        rules = p.setdefault("complex_modifications", {}).setdefault("rules", [])
        if not any(r.get("description") == desc for r in rules):
            rules.extend(rule["rules"])
            changed = True
        break
if changed:
    json.dump(cfg, open(cfg_path, "w"), ensure_ascii=False, indent=4)
    print("    ✓ 已合并启用（原配置备份于 %s）" % bak)
else:
    print("    ✓ 规则已在启用列表中，跳过")
PY
}

# ---------------------------------------------------------------- 7. 权限值守
# macOS 安全模型不允许脚本直接授予 TCC 权限（输入监控/辅助功能）和
# DriverKit 驱动扩展开关。能自动化的极限是：
#   · 自动触发系统授权弹窗（Karabiner 启动时自己弹）
#   · 自动打开精确的系统设置页
#   · 轮询授权状态，完成即自动继续，不再需要人盯
PERM_JSON="$HOME/.local/share/karabiner/tmp/core-service-permission-check-result.json"
WAIT_TIMEOUT="${RCV_WAIT_TIMEOUT:-600}"   # 值守超时秒数，可用环境变量覆盖

perm_status() {
  # 输出: ok / accessibility / iohid / none（表示文件还不存在）
  [ -f "$PERM_JSON" ] || { echo "none"; return; }
  python3 - "$PERM_JSON" <<'PY'
import json, sys
try:
    d = json.load(open(sys.argv[1]))
except Exception:
    print("none"); raise SystemExit
a = d.get("accessibility_process_trusted", False)
i = d.get("iohid_listen_event_allowed", False)
if a and i: print("ok")
elif not a: print("accessibility")
elif not i: print("iohid")
PY
}

driver_status() {
  systemextensionsctl list 2>/dev/null | grep -q 'Karabiner-DriverKit-VirtualHIDDevice' || { echo "missing"; return; }
  if systemextensionsctl list 2>/dev/null | grep 'Karabiner-DriverKit-VirtualHIDDevice' | grep -q '\[activated enabled\]'; then
    echo "ok"
  else
    echo "waiting"
  fi
}

open_pane() {
  case "$1" in
    listen)  open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" 2>/dev/null || true ;;
    ax)      open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" 2>/dev/null || true ;;
    driver)  open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension" 2>/dev/null || true ;;
  esac
}

wait_permissions() {
  step "5/6 系统授权值守（弹窗出现时点「允许」即可，其余交给脚本）"

  # 先拉起 Karabiner，让它触发授权弹窗
  [ "$DRY_RUN" -eq 1 ] || open -a "Karabiner-Elements" 2>/dev/null || true

  local waited=0
  local last_hint=""
  while [ "$waited" -lt "$WAIT_TIMEOUT" ]; do
    local p d
    p="$(perm_status)"
    d="$(driver_status)"

    if [ "$p" = "ok" ] && [ "$d" = "ok" ]; then
      say "    ✓ 全部授权完成（辅助功能 ✓ 输入监控 ✓ 驱动扩展 ✓）"
      return 0
    fi

    local hint
    if [ "$p" = "none" ] || [ "$p" = "iohid" ]; then
      hint="listen"
    elif [ "$p" = "accessibility" ]; then
      hint="ax"
    elif [ "$d" = "waiting" ]; then
      hint="driver"
    else
      hint=""
    fi

    if [ -n "$hint" ] && [ "$hint" != "$last_hint" ]; then
      case "$hint" in
        listen)
          say "    · 等待「输入监控」授权 —— 若弹窗出现点允许；否则请在刚打开的系统设置页把 Karabiner 开关打开"
          ;;
        ax)
          say "    · 等待「辅助功能」授权 —— 若弹窗出现点「打开系统设置」并允许"
          ;;
        driver)
          say "    · 等待「驱动扩展」—— 系统设置 → 登录项与扩展 → 驱动扩展 → 打开 Karabiner-DriverKit-VirtualHIDDevice"
          ;;
      esac
      [ "$DRY_RUN" -eq 1 ] || open_pane "$hint"
      last_hint="$hint"
    fi

    [ "$DRY_RUN" -eq 1 ] && return 0
    sleep 5
    waited=$((waited + 5))
  done

  say "    ! 等待超时（${WAIT_TIMEOUT}s）。授权还没全部完成，可稍后重跑本脚本继续值守。"
  return 1
}

ensure_karabiner
install_rule
enable_rule_in_config
ensure_minimal_config
wait_permissions
open_import

if [ "$ACTION" = "switch" ]; then
  BIND_STEP="  ③ 绑定目标
     不需要。switch 档单击右 Command 直接发 ⌃Space，跟输入法无关。"
elif [ "$KEY" = "fnspace" ]; then
  BIND_STEP="  ③ 绑定目标
     不需要。fnspace 档发的就是微信输入法的默认语音快捷键 Fn+Space。
     只需确认微信输入法 → 设置 → 快捷键 → 语音输入 仍是 Fn+Space，
     模式选「连续 / 免提」—— 单击开始、再单击结束。"
else
  BIND_STEP="  ③ 绑定目标
     微信输入法 → 设置 → 快捷键 → 语音输入 → 录成 $(echo "$KEY" | tr '[:lower:]' '[:upper:]')
     模式选「连续 / 免提」—— 单击开始、再单击结束。
     不设免提的话，会变成按住说话，单击只闪一下。"
fi

cat <<EOF

────────────────────────────────────────────
完成情况：
  ✓ 规则已预启用进 karabiner.json（不需要手动 Add rule）
  ✓ 系统授权已值守完成（若上面显示 ✓）
     —— macOS 不允许脚本直接授予 TCC 权限和驱动扩展开关，
        这是弹窗/开关各点一次的理论下限，脚本负责其余一切。

$BIND_STEP

验证：
  输入框里点一下右 Command → 触发
  按住右 Command + C       → 仍然复制（说明长按还是 ⌘）

排查：docs/troubleshooting.md（第一步就是用 Karabiner-EventViewer 看输出）
卸载：./uninstall.sh
────────────────────────────────────────────
EOF
