#!/usr/bin/env bash
# Right Cmd Voice · 卸载
# 只移除本项目写入的规则文件，不动 Karabiner 里的其他配置。
set -uo pipefail

ASSETS="$HOME/.config/karabiner/assets/complex_modifications"
removed=0

for f in "$ASSETS"/right_cmd_voice*.json; do
  [ -e "$f" ] || continue
  rm -f "$f"
  echo "已删除: $f"
  removed=$((removed + 1))
done

if [ "$removed" -eq 0 ]; then
  echo "没有找到本项目的规则文件（可能已经卸过了）"
fi

cat <<'EOF'

还有两步需要手动做（Karabiner 只允许在界面里管理已启用规则）：

1) 打开 Karabiner-Elements → Complex Modifications
   把「Right Cmd →」开头的规则 Remove

2) 微信输入法 → 设置 → 快捷键 → 语音输入
   把绑定的 F18 清掉

想彻底卸载 Karabiner：
  brew uninstall --cask karabiner-elements
  （卸载后需要重启，虚拟键盘驱动才会释放）
EOF
