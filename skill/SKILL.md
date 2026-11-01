---
name: right-cmd-voice
description: 把 macOS 的右 Command 键改成「单击触发某个动作、长按仍然是 Command」。当用户说「右 Command 单击切换输入法 / 呼出语音输入 / 改成某某键」「右 cmd 改键」「right command 单击」「把右 command 设成 …」时使用。实现方式为 Karabiner-Elements 的 to_if_alone，不破坏 ⌘C/⌘V 等组合键。
---

# 右 Command 单击改造

目标：让**单击右 Command** 触发用户指定的动作，同时**按住右 Command** 仍然当标准 ⌘ 修饰键使用。

## 先判断：可能根本不需要装东西

macOS 的系统级热键不接受「裸修饰键」，但**微信输入法**这类自带按键监听（配置里有 `tapCount` 字段）的输入法有可能直接支持。

**动手装 Karabiner 之前，先用一句话让用户试 10 秒：**

> 微信输入法 → 设置 → 快捷键 → 语音输入 / 中英文切换 → 录制 → 单按右 Command

- 能录进去 → 直接用，**不要装 Karabiner**，告诉用户已经完成
- 录不进去 / 按下去毫无反应 → 走下面的方案

## 方案：Karabiner-Elements + to_if_alone

三层结构：物理按键 → Karabiner 区分单击/长按 → 输出标准键 → 输入法或系统响应。

### 步骤 1 · 自检

```bash
uname -m; sw_vers
ls -d /Applications/Karabiner-Elements.app 2>/dev/null
ls -d "/Library/Input Methods/WeType.app" 2>/dev/null
defaults read com.apple.HIToolbox AppleEnabledInputSources 2>/dev/null | head -40
```

记录：是否已装 Karabiner、目标输入法是否在活动输入源里。

### 步骤 2 · 安装 Karabiner（没装才装）

```bash
brew install --cask karabiner-elements
```

会要求输入密码。装完必须重启 `karabiner_grabber`，否则规则不生效。

### 步骤 3 · 写入规则

规则写入 `~/.config/karabiner/assets/complex_modifications/`，文件名用 `right_cmd_voice.json`。

**默认档（单击 → F18，给输入法绑语音输入）：**

```json
{
  "title": "Right Cmd → F18（语音输入）",
  "rules": [
    {
      "description": "右 Command 单击 → F18；按住时仍是 Command 修饰键",
      "manipulators": [
        {
          "type": "basic",
          "from": {
            "key_code": "right_command",
            "modifiers": { "optional": ["any"] }
          },
          "to": [{ "key_code": "right_command", "lazy": true }],
          "to_if_alone": [{ "key_code": "f18" }]
        }
      ]
    }
  ]
}
```

三个字段各自的作用，改动时别弄错：

| 字段 | 作用 | 改错会怎样 |
|---|---|---|
| `to` + `"lazy": true` | 组合键场景才补发真正的 ⌘ | 漏掉 → 所有 ⌘ 组合键失效 |
| `to_if_alone` | 单按松开时发 F18 | 改成 `to` → 单击变成长按，永远发 F18 |
| `from.modifiers.optional: ["any"]` | 允许 ⌘+任意键匹配 | 漏掉 → 组合键匹配不到，走不到 `to` |

**换档：** `f18` 录不进去就换 `f13`；想直接切输入法就把 `to_if_alone` 改成：

```json
[{ "key_code": "spacebar", "modifiers": ["left_control"] }]
```

### 步骤 4 · 唤起导入

```bash
DEST="$HOME/.config/karabiner/assets/complex_modifications/right_cmd_voice.json"
open -a "Karabiner-Elements"
ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote('file://'+sys.argv[1], safe=''))" "$DEST")
open "karabiner://karabiner/assets/complex_modifications/import?url=$ENC"
```

### 步骤 5 · 必须由用户手动完成的两步

**这两步不能用脚本代替，也不要声称已经完成。**

1. Karabiner-Elements → `Complex Modifications` → `Add rule` → 启用「Right Cmd →」
2. 系统设置 → 隐私与安全性 → **输入监控** + **辅助功能** → 勾选 Karabiner 相关项

然后把目标动作绑到输出键上（例：微信输入法 → 设置 → 快捷键 → 语音输入 → 录 `F18`）。

### 步骤 6 · 验证

让用户依次试：

| 操作 | 期望 |
|---|---|
| 输入框里点一下右 Command | 目标动作触发 |
| 按住右 Command + C | 正常复制（说明长按仍为 ⌘） |
| 按住右 Command + Tab | 正常切 App |
| 左 Command | 完全不受影响 |

## 排障顺序

1. 打开 `Karabiner-EventViewer` → Main 页 → 点右 Command
   - 只有 `right_command`、没有 `f18` → 规则没 Enable
   - 什么都没有 → `karabiner_grabber` 没跑 / 没授权输入监控
   - 有 `f18` → 键位层 OK，问题在输入法绑定
2. 长按也触发 → 检查 `to` 的 `lazy`，或加 `"parameters": {"basic.to_if_alone_timeout_milliseconds": 250}`
3. 外接键盘按右 ⌘ 没反应 → 用 EventViewer 确认它报的是 `right_command` 还是 `right_option`，后者要把 JSON 里的键名换掉

## 边界

- 只做键位，不改输入法配置。输入法里的快捷键需要用户自己在设置里录。
- 不卸载用户的 Karabiner 或清空其他规则；卸载时只删本项目的 JSON。
- 用户明确说「不要装第三方驱动」时，退回方案 A 或建议用系统设置把 Caps Lock 设为切换键。
