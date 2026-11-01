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
#   --key <f18|f13|f14|f15|...>   单击时输出的键，默认 f18
#   --action <voice|switch>       voice = 给输入法绑语音输入（默认）；switch = 直接切输入法
#   --dry-run                     只打印将要做什么，不落盘
#   -h, --help
#
# 做的事：装 Karabiner-Elements → 写规则 → 唤起导入。
# 不做的事：启用规则、系统授权、输入法绑定 —— 这三步必须人手动点。
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
  --key <f18|f13|...>     单击时输出的键，默认 f18
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
  step "1/4 检查 Karabiner-Elements"
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
  step "3/4 检查 karabiner.json"
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
  step "2/4 写入规则文件"
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
  step "4/4 唤起 Karabiner 导入"
  if [ "$DRY_RUN" -eq 1 ]; then
    say "    [dry-run] 打开 karabiner:// 导入链接"
    return 0
  fi
  open -a "Karabiner-Elements" 2>/dev/null || true
  local enc
  enc="$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote('file://'+sys.argv[1], safe=''))" "$RULE_FILE")"
  open "karabiner://karabiner/assets/complex_modifications/import?url=$enc" 2>/dev/null || {
    say "    ! 深链没打开，手动导入：Karabiner-Elements → Complex Modifications → Add rule（旧版 Add predefined rule）"
  }
}

ensure_karabiner
install_rule
ensure_minimal_config
open_import

if [ "$ACTION" = "switch" ]; then
  BIND_STEP="  ③ 绑定目标
     不需要。switch 档单击右 Command 直接发 ⌃Space，跟输入法无关。"
else
  BIND_STEP="  ③ 绑定目标
     微信输入法 → 设置 → 快捷键 → 语音输入 → 录成 $(echo "$KEY" | tr '[:lower:]' '[:upper:]')
     模式选「连续 / 免提」—— 单击开始、再单击结束。
     不设免提的话，会变成按住说话，单击只闪一下。"
fi

cat <<EOF

────────────────────────────────────────────
脚本能做的都做完了。剩下三步 Apple 不允许脚本代劳：

  ① 启用规则
     Karabiner-Elements → Complex Modifications → Add rule（旧版 Add predefined rule）
     → 找到「右Command单按」开头那条 → Enable

  ② 系统授权（首次必须）
     系统设置 → 隐私与安全性 → 输入监控 和 辅助功能
     → 勾选 Karabiner 相关项 → 注销重登或重启

$BIND_STEP

验证：
  输入框里点一下右 Command → 触发
  按住右 Command + C       → 仍然复制（说明长按还是 ⌘）

排查：docs/troubleshooting.md（第一步就是用 Karabiner-EventViewer 看输出）
卸载：./uninstall.sh
────────────────────────────────────────────
EOF
