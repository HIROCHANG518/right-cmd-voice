# 故障排查

按顺序走，绝大多数问题在前三条。

---

## 1. 单击完全没反应

**先看底层到底发出了什么。**

打开 `Karabiner-EventViewer`（装 Karabiner 时自带，也可以在 Spotlight 里搜），切到 **Main** 页，点一下右 Command：

| EventViewer 里看到 | 说明 | 处理 |
|---|---|---|
| `right_command` 直接出现，没有 `f18` | 规则没生效 | 去 `Complex Modifications` 确认规则是 Enabled 状态 |
| 什么都没有 | `karabiner_grabber` 没跑 / 没授权 | 系统设置 → 隐私与安全性 → 输入监控，勾上 Karabiner；然后注销重登 |
| `f18` 出现了 | 键位层没问题，是输入法那边没绑上 | 去微信输入法重新录快捷键 |

**授权是最常见的坑**：Karabiner 装完首次运行会弹两个权限请求，只点了「稍后」的话规则是哑的。

---

## 2. 长按 ⌘C 也触发了语音

说明 `to_if_alone` 的超时判断把「按住」也算成「单击」了，或者 `to` 那行的 `lazy` 没生效。

- 确认 JSON 里 `to` 是 `{"key_code": "right_command", "lazy": true}`，**不是**省略 `to` 的写法
- 想更严格一点，给 manipulator 加超时：

```json
"parameters": {
  "basic.to_if_alone_timeout_milliseconds": 250
}
```

默认是 1000ms。改成 250 意味着按超过 0.25 秒再松手就不触发，适合手速快的人；手速慢的人反而要调大。

---

## 3. 单击太"粘"，要按两下才触发

反过来，是超时太短了。调大 `basic.to_if_alone_timeout_milliseconds`（比如 400）。

---

## 4. 微信输入法录不到 F18

有些录制器只认真实存在的字符键。换档：

```bash
./uninstall.sh
./install.sh --key f13
```

F13/F14/F15 在 Mac 键盘上并不存在，但虚拟键码是在的，Karabiner 能发，多数录制器也能收。F18 不行就试 F13。

仍然录不到的话，改用 `./install.sh --action switch`，绕开输入法，直接触发系统的「选择上一个输入法」。

---

## 5. ⌘ 组合键部分失效

通常是**多条规则抢同一个键**。检查：

- Karabiner 里是否同时启用了别的把 `right_command` 当 `from` 的规则
- 是否装过「Caps Lock → Hyper」之类的老规则，和本规则叠加

排查方法：`Complex Modifications` 里先全部 Disable，只留本项目这一条。

---

## 6. 语音输入弹不出来，但 EventViewer 有 f18

不是键位问题。依次确认：

- 光标在**可输入的文本框**里（桌面、Finder 里按是不会弹的）
- 微信输入法本身处于活动输入法状态（输入法菜单里它是当前项）
- 微信输入法有辅助功能权限：系统设置 → 隐私与安全性 → 辅助功能
- 微信输入法 → 设置 → 快捷键 → 语音输入，确认快捷键那一栏真的是 `F18`

---

## 7. 外接键盘（非 Apple 键盘）

大多数机械键盘右侧的 ⌘ 位（其实是 Alt 位）被系统识别成 `right_option` 或 `right_command` 都有可能。

先跑 `Karabiner-EventViewer` 按一下，看它报的是 `right_command` 还是 `right_option`。如果是后者，把 JSON 里所有 `right_command` 换成 `right_option` 再装。

不确定的话，Karabiner 的 `Devices` 页可以按键盘分别配置，外接和内置互不影响。

---

## 8. macOS 大版本升级后失效

系统升级（尤其 26.x 这类）会重置输入监控授权，也会重新审核 DriverKit 扩展。

处理：系统设置 → 隐私与安全性，看有没有「Karabiner 的系统扩展被阻止」的提示，允许后重启。Karabiner 版本也要跟着升：`brew upgrade --cask karabiner-elements`。

---

## 9. 想临时关掉

Karabiner 菜单栏图标 → `Complex Modifications` 里 Disable 掉即可，不用卸载。或者 `./uninstall.sh` 移除规则文件。
