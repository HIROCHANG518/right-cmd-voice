# 为什么「单击右 Command」这么难

## 1. macOS 的热键模型：键码 + 修饰键

应用注册全局热键走 `RegisterEventHotKey`（Carbon，现在依然是最稳的一条路），签名长这样：

```c
RegisterEventHotKey(keyCode, modifiers, hotKeyID, target, options, &ref);
```

它要一个**非修饰键的虚拟键码**，加一组**修饰键掩码**。而 Command 键本身是修饰键，它在系统里的作用是「给后面的键加前缀」，单独按下时不构成一个「键码」，所以：

```
右 Command 单击  →  没有 keyCode  →  不产生 hotKey 事件  →  录制控件当没按
```

各种「快捷键录制」控件（包括输入法和绝大多数 App 的设置页）都是在 `keyDown` 里取 `event.keyCode`，遇到纯 modifier 的 keyDown 直接丢弃。这就是为什么你在录制框里按半天右 Command，它一点反应都没有。

## 2. 微信输入法的例外

微信输入法的配置文件里，快捷键是这么存的：

```
~/Library/Application Support/WeType/mmkv/wetype.settings
  voicePTTShortcut_keyCodes
  voicePTTShortcut_modifiers
  voicePTTShortcut_tapCount        ← 按几下
  voiceToggleShortcut_keyCodes
  voiceToggleShortcut_modifiers
  voiceToggleShortcut_tapCount
  settingfunction_inputModeHotKey
```

`tapCount` 这个维度说明它走的是**自建全局按键监听**（通常是 CGEventTap），而不是 Carbon 热键。自建监听能拿到裸修饰键的 keyDown，理论上就能把「单击右 Command」表达出来。

所以这条路「可能通」，但要看它录制器有没有做过滤。**10 秒就能验证**，值得先试。

## 3. Karabiner 的 to_if_alone

Karabiner-Elements 跑在 HID 层（DriverKit 虚拟键盘 + karabiner_grabber 抓原始事件），比应用层的 CGEventTap 更靠前，所以它有能力重新定义「什么算一次按键」。

核心是这一个字段：

```json
{
  "from": { "key_code": "right_command", "modifiers": { "optional": ["any"] } },
  "to":   [ { "key_code": "right_command", "lazy": true } ],
  "to_if_alone": [ { "key_code": "f18" } ]
}
```

逐行读：

| 字段 | 作用 |
|---|---|
| `from.modifiers.optional: ["any"]` | 右 Command 后面跟任何修饰键组合都要匹配 |
| `to` + `lazy: true` | 真正的右 Command 先「扣着不发」，只有当后面又按了别的键（⌘C）时才补发出去 —— 保证组合键不受影响 |
| `to_if_alone` | 如果这个键被**单独按下又松开**（默认 1 秒内），就不发 Command，改发 F18 |

于是同一个物理键有了两种语义：**单击 → F18，按住当修饰 → ⌘**。这就是「重新设定右 Command」的技术本质。

## 4. 为什么不用 hidutil

macOS 自带的 `hidutil` 能做键码重映射：

```bash
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc":0x7000000E7,
                                            "HIDKeyboardModifierMappingDst":0x70000006C}]}'
```

但它只能**整键替换**：右 Command 一旦变成 F18，右手所有 ⌘ 组合键当场全废。而且不持久，重启失效，得挂 LaunchDaemon。做不到「单击 / 长按分离」这件事。

## 5. 为什么不用 Caps Lock 那条路

macOS 系统设置里可以把 Caps Lock 设成「切换输入法」，这是系统内置的、零依赖的方案。但它绑死在 Caps Lock 上，改不了右 Command，也没有 tap/long-press 的区分。可以作为对照组理解：系统愿意为你做的，只是把某个键**整个**改成切换键。
