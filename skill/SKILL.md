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

> brew 沙箱在某些环境下报 `sandbox-exec: sandbox_apply: Operation not permitted`，
> `HOMEBREW_NO_SANDBOX=1` 也压不住时，改走官方 dmg：
> 从 `https://api.github.com/repos/pqrs-org/Karabiner-Elements/releases/latest` 取 dmg，
> `hdiutil attach` 后用 `osascript -e 'do shell script "installer -pkg <pkg> -target /" with administrator privileges'`
> 安装（会弹系统密码框，用户输一次密码即可）。

### 步骤 3 · 写入规则并预启用

规则写入 `~/.config/karabiner/assets/complex_modifications/`，文件名用 `right_cmd_voice.json`。

**关键：不要让用户手动 Add rule。** 直接把规则合并进 `~/.config/karabiner/karabiner.json`：

- 没有 `karabiner.json` → 写入一份含该规则的最小配置（规则处于启用状态）
- 已有 → 先备份（`karabiner.json.bak.<时间戳>`），再把 rule 追加进 selected profile 的
  `complex_modifications.rules`（按 description 去重，不碰其它配置）

`install.sh` 的新版已内置这一步；手动做时参考仓库里 `install.sh` 的
`enable_rule_in_config` 函数。

**默认档（单击 → F18，给输入法绑语音输入）：**

```json
{
  "title": "右Command单按触发语音输入（F18）",
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

### 步骤 4 · 唤起导入（可选兜底）

步骤 3 已经把规则预启用进 `karabiner.json`，理论上不需要这一步。
保留它只为一种情况：用户想通过 Karabiner 界面看到并管理这条规则。

```bash
DEST="$HOME/.config/karabiner/assets/complex_modifications/right_cmd_voice.json"
open -a "Karabiner-Elements"
ENC=$(python3 -c "import urllib.parse,sys;print(urllib.parse.quote('file://'+sys.argv[1], safe=''))" "$DEST")
open "karabiner://karabiner/assets/complex_modifications/import?url=$ENC"
```

### 步骤 5 · 权限值守（尽量自动化，不要让用户自己翻设置）

**为什么之前装的时候没有手动步骤、这次却有？**
macOS 的 TCC 授权（辅助功能、输入监控）和 DriverKit 驱动扩展开关是**按机器授权**的，
Apple 不提供任何脚本 API 直接授予。之前的机器上这些授权早就给过（Karabiner 装过并勾过），
所以看起来全自动；换一台新机器，这三样第一次都必须由人点一下 —— 这是 macOS 的安全下限，
任何声称能全自动跳过的方案都在骗人（要么关 SIP，要么 MDM）。

**脚本能自动化的极限（新版 install.sh 已内置，见 `wait_permissions` 函数）：**

1. 自动拉起 Karabiner，让 macOS 自己弹授权弹窗 —— 用户只点弹窗里的「允许」
2. 自动打开精确的系统设置深链，用户不用自己翻：
   - 输入监控：`open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"`
   - 辅助功能：`open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"`
   - 驱动扩展：`open "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"`
3. 轮询授权状态，每项完成即自动进入下一项，全程不需要人盯：
   - TCC 状态：`~/.local/share/karabiner/tmp/core-service-permission-check-result.json`
     （`accessibility_process_trusted` / `iohid_listen_event_allowed`）
   - 驱动状态：`systemextensionsctl list` 里 Karabiner-DriverKit-VirtualHIDDevice 是否 `[activated enabled]`
4. 已授权的机器上轮询瞬间通过 → 零手动步骤，和之前一样

**AI 助手值守时的加分动作：** 如果你有截屏能力，每 30 秒截一次屏看用户卡在哪一步
（列表是空的？弹窗没点？），用一句话告诉用户下一步点哪里，比让用户描述快得多。

**输入监控列表为空的坑（macOS 15+ 常见）：** Karabiner-Core-Service 可能不在列表里，
需要点 + 手动添加：`Cmd+Shift+G` →
`/Library/Application Support/org.pqrs/Karabiner-Elements/` → 选 `Karabiner-Core-Service.app`。

**用户只需做的物理动作（无法再压缩）：**

1. 授权弹窗 / 系统设置页里的「允许」和开关（各一次）
2. 把目标动作绑到输出键上（例：微信输入法 → 设置 → 快捷键 → 语音输入 → 录 `F18`，
   模式选「连续 / 免提」）

> 不要试图直接改微信输入法的 MMKV 配置文件
> （`~/Library/Application Support/WeType/mmkv/`，键如 `voiceToggleShortcut_keyCodes`），
> 它是带 CRC 校验的 mmap 二进制，手写有损坏配置的风险。UI 录制是最安全的路径。

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
