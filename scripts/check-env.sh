#!/usr/bin/env bash
# Right Cmd Voice · 环境自检
# 只读，不修改任何东西。安装前后都可以跑一遍。
set -uo pipefail

line() { printf '%s\n' "────────────────────────────────────────────"; }

line
echo "系统"
sw_vers | sed 's/^/  /'
echo "  芯片: $(uname -m)"

line
echo "Karabiner-Elements（键位层）"
KB_APP="/Applications/Karabiner-Elements.app"
if [ -d "$KB_APP" ]; then
  KB_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$KB_APP/Contents/Info.plist" 2>/dev/null || echo "?")
  echo "  ✓ 已安装 v$KB_VER"
  if pgrep -x karabiner_grabber >/dev/null 2>&1; then
    echo "  ✓ karabiner_grabber 正在运行"
  else
    echo "  ! karabiner_grabber 未运行（可能未授权输入监控，或刚装完还没启动）"
  fi
else
  echo "  ✗ 未安装 —— 运行 ./install.sh 会自动装"
fi

line
echo "输入法"
WT="/Library/Input Methods/WeType.app"
if [ -d "$WT" ]; then
  WT_VER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$WT/Contents/Info.plist" 2>/dev/null || echo "?")
  echo "  ✓ 微信输入法 v$WT_VER"
else
  echo "  ✗ 未检测到微信输入法（/Library/Input Methods/WeType.app）"
fi

echo "  已启用的输入源:"
defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null \
  | python3 -c "
import sys,re
txt = sys.stdin.read()
names = re.findall(r'\"?KeyboardLayout Name\"?\s*=\s*\"?([^\";]+)\"?;', txt)
names += re.findall(r'\"?Bundle ID\"?\s*=\s*\"?([^\";]+)\"?;', txt)
line = re.findall(r'\"?Input Mode Name Key\"?\s*=\s*\"?([^\";]+)\"?;', txt)
out = sorted(set(n.strip() for n in names + line))
print('\n'.join('    · '+o for o in out) if out else '    · (读取为空)')
" 2>/dev/null || echo "    · (读取失败)"

line
echo "已安装的本项目规则"
ASSETS="$HOME/.config/karabiner/assets/complex_modifications"
if compgen -G "$ASSETS/right_cmd_voice*.json" >/dev/null 2>&1; then
  ls -1 "$ASSETS"/right_cmd_voice*.json | sed 's/^/  · /'
else
  echo "  （无）"
fi

echo "Karabiner 里已启用的规则数:"
python3 - "$HOME/.config/karabiner/karabiner.json" <<'PY' 2>/dev/null || echo "  （读取失败或无配置文件）"
import json, sys
try:
    cfg = json.load(open(sys.argv[1]))
except Exception:
    print("  （无配置文件）"); raise SystemExit
sel = cfg.get("profiles", [{}])[cfg.get("selected_profile_index", 0) if isinstance(cfg.get("selected_profile_index"), int) else 0]
rules = sel.get("complex_modifications", {}).get("rules", [])
print(f"  {len(rules)} 条")
for r in rules:
    if "Right Command" in r.get("description", ""):
        print("  · " + r["description"])
PY

line
echo "提示：装完规则后如果单击没反应，先跑 Karabiner-EventViewer，"
echo "      点一下右 Command，看它输出的是不是 f18 / f13。"
line
