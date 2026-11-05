# right-cmd-voice

![platform](https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey)
![license](https://img.shields.io/badge/license-MIT-blue)
![requires](https://img.shields.io/badge/requires-Karabiner--Elements-orange)

把 macOS 的**右 Command 键**改成「单击触发、长按不变」：

- **单击**右 Command → 呼出微信输入法的语音输入
- **按住**右 Command + 字母 → 仍是标准 ⌘，⌘C / ⌘V / ⌘Tab 完全照旧
- 左 Command 不受任何影响

一条命令装完：

```bash
curl -fsSL https://raw.githubusercontent.com/HIROCHANG518/right-cmd-voice/main/install.sh | bash
```

---

## 它做什么

| 你的操作 | 结果 |
|---|---|
| 单击右 Command | 触发你绑定的动作（默认发给输入法 `F18`） |
| 按住右 Command + C | 复制，和以前一样 |
| 按住右 Command + Tab | 切 App，和以前一样 |
| 左 Command | 完全不受影响 |

---

## 为什么需要中间这一层

macOS 的全局热键（Carbon `RegisterEventHotKey`）只接受「键码 + 修饰键组合」，**单独的修饰键按下不产生热键事件**。所以任何用标准录制器采集快捷键的 App，你按右 Command 它都当没按。

Karabiner-Elements 跑在 HID 层，能用 `to_if_alone` 把同一个物理键拆成两种语义：

```json
"from":  { "key_code": "right_command", "modifiers": { "optional": ["any"] } },
"to":    [ { "key_code": "right_command", "lazy": true } ],
"to_if_alone": [ { "key_code": "f18" } ]
```

`lazy: true` 是关键——真正的 ⌘ 被扣住不发，只有后面又按了别的键才补发，所以组合键不受影响；单按松开时才走 `to_if_alone`。

细节和为什么 `hidutil` 做不到，见 [docs/how-it-works.md](docs/how-it-works.md)。

> **先花 10 秒试一次再装**：微信输入法的快捷键配置里有 `tapCount`（按几下）字段，说明它用的是自建按键监听，**有可能直接支持单击右 Command**。微信输入法 → 设置 → 快捷键 → 语音输入 → 录制 → 单按右 Command。能录进去就不用装这个项目。

---

## 安装

### 方式一：一条命令

```bash
curl -fsSL https://raw.githubusercontent.com/HIROCHANG518/right-cmd-voice/main/install.sh | bash
```

### 方式二：先审脚本再跑（推荐给谨慎的人）

```bash
git clone https://github.com/HIROCHANG518/right-cmd-voice.git
cd right-cmd-voice
less install.sh          # 先看一遍
./install.sh             # 再跑
```

脚本会：装 Homebrew（没有的话）→ 装 Karabiner-Elements → 写规则到 `~/.config/karabiner/assets/complex_modifications/` → 唤起 `karabiner://` 导入链接。

**幂等**：重复跑不会出错，规则已是最新就直接跳过。

### 然后只需要点几下（脚本值守，不用自己翻设置）

脚本会自动把规则预启用进 `karabiner.json`（不需要手动 Add rule），并进入授权值守：
自动弹授权窗、自动打开精确的系统设置页、轮询到全部完成才继续。

Apple 的安全模型不允许任何脚本直接授予 TCC 权限和驱动扩展开关，所以这几个「点一下」省不掉：

**① 授权弹窗 / 开关（值守中按提示点即可）**
- 弹窗出现 → 点「允许」
- 输入监控列表为空时：点 + → `Cmd+Shift+G` →
  `/Library/Application Support/org.pqrs/Karabiner-Elements/` → 选 `Karabiner-Core-Service.app`
- 驱动扩展：系统设置 → 登录项与扩展 → 驱动扩展 → 打开 Karabiner-DriverKit-VirtualHIDDevice
（已授权过的机器上，值守瞬间通过，零操作）

**② 绑定目标**
微信输入法 → 设置 → 快捷键 → 语音输入 → 录成 `F18`
**模式选「连续 / 免提」**——单击开始，再单击结束。不设免提的话会变成按住说话，单击只闪一下。

---

## 验证

| 操作 | 期望 |
|---|---|
| 输入框里点一下右 Command | 语音输入弹出 |
| 按住右 Command + C | 正常复制 |
| 左 Command | 一切照旧 |

不通过就看 [docs/troubleshooting.md](docs/troubleshooting.md)。第一步永远是打开 `Karabiner-EventViewer`，点一下右 Command，看它到底输出了什么——比猜快得多。

---

## 参数

| 参数 | 说明 |
|---|---|
| `--key f18` | 单击时输出的键，默认 `f18`。录不进去换 `f13` |
| `--key fnspace` | 发 `Fn+Space`。**微信输入法的语音快捷键默认就是它**，这一档不用改输入法任何设置 |
| `--action voice` | 默认。给输入法绑语音输入 |
| `--action switch` | 不碰输入法，直接发 `⌃Space` 切输入法 |
| `--dry-run` | 只打印要做什么，不落盘 |

```bash
./install.sh --key fnspace    # 微信输入法免配置，最省事
./install.sh --key f13        # F18 录不进去时降级
./install.sh --action switch  # 绕开输入法，直接切输入法
```

三档怎么选：

| 场景 | 用哪档 |
|---|---|
| 微信输入法，且快捷键保持默认 | `--key fnspace`（推荐先试这个） |
| 微信输入法，语音快捷键已手动改成 F18 | `--key f18`（默认） |
| 不想碰输入法 / 想一键切中英 | `--action switch` |

> **实测推荐**：默认 F18 档 + 在微信输入法里直接按右 ⌘ 录制（Karabiner 会替你转好）。**不要用 `fnspace` 档**，除非你确定没有其它 App 抢 `fn` 标志位——`fn` 被 Globe 键、输入法按住说话、Typeless 等多方争抢，残留后 ⌘ 组合键会全部失灵。

---

## 契约

**保证**

- 只写 `~/.config/karabiner/assets/complex_modifications/right_cmd_voice.json`，不动你已有的其他 Karabiner 规则
- 不改任何系统设置，不写 LaunchDaemon，不装开机自启
- `--dry-run` 下不产生任何写入
- `uninstall.sh` 只删本项目文件

**不保证**

- 不保证免手动：启用规则、系统授权、输入法绑定必须你点
- 不保证微信输入法认 `F18`：不认就换 `--key f13`
- 不处理外接键盘的键位差异：有些键盘右侧 ⌘ 上报的是 `right_option`，见 troubleshooting 第 7 条

---

## FAQ

**Q：会不会让我的 ⌘C 失效？**
不会。`to` 里是 `lazy: true`，组合键场景会补发真正的 Command。

**Q：为什么是 F18 这种奇怪的键？**
F18 在实体键盘上不存在，但虚拟键码在，冲突概率最低。Karabiner 能发，多数快捷键录制器能收。

**Q：微信输入法录不到 F18 怎么办？**
`./install.sh --key f13`，F13/F14/F15 依次试。再不行用 `--action switch` 绕开输入法。

**Q：能改成切换中英文而不是语音输入吗？**
能。用 `--action switch`（走系统「选择上一个输入法」），或者在微信输入法里把「中英文切换」绑到同一个键。

**Q：macOS 升级后失效？**
升级会重置输入监控授权。系统设置里重新勾选，再 `brew upgrade --cask karabiner-elements`。

**Q：能只对外接键盘生效吗？**
能，在 Karabiner 的 `Devices` 页按设备单独配置，或用 `device_if` 条件。默认规则对所有键盘生效。

---

## 目录结构

```
right-cmd-voice/
├── install.sh                      # 一键安装（支持 curl | bash）
├── uninstall.sh                    # 只删本项目规则
├── rules/
│   ├── right_cmd_voice.json        # 右⌘单按 → F18，组合键不变
│   └── right_cmd_voice_switch.json # 右⌘单按 → ⌃Space（备选）
├── scripts/check-env.sh            # 只读自检
├── skill/SKILL.md                  # 让 AI 助手一句话完成配置
├── docs/
│   ├── how-it-works.md
│   └── troubleshooting.md
├── LICENSE
└── .gitignore
```

`rules/` 里的文件是给你手动导入 / 阅读用的；`install.sh` 按参数生成语义相同的 JSON。

---

## 卸载

```bash
./uninstall.sh
```

然后去 Karabiner 界面把规则 `Remove`，在输入法里清掉 `F18`。想彻底删：`brew uninstall --cask karabiner-elements`（之后要重启才会释放虚拟键盘驱动）。

---

## 给 AI 助手用

把 `skill/` 目录拷到 `~/.workbuddy/skills/`，之后对助手说「帮我把右 Command 单击设成语音输入」，它会跑自检、装 Karabiner、导规则，并把剩下必须手动的两步列清楚。

---

## 发布到 GitHub

仓库已经在本地 `git init` 过的话，直接：

```bash
# 先在 GitHub 网页 New repository → 命名 right-cmd-voice（不要勾 README/LICENSE/.gitignore）
git remote add origin git@github.com:HIROCHANG518/right-cmd-voice.git
git branch -M main
git push -u origin main
```

从零开始的话：

```bash
git init
git add .
git commit -m "init: right cmd voice trigger (F18)"
git remote add origin git@github.com:HIROCHANG518/right-cmd-voice.git
git branch -M main
git push -u origin main
```

### 发布后自检

1. 换一台机器（或删掉本地配置后）跑一遍 `curl | bash`，确认不报错
2. 打开 Karabiner，确认规则能正常加载、没有 schema 报错
3. 单按右 ⌘，看 `Karabiner-EventViewer` 是否输出 `f18`
4. 微信输入法绑 `F18` + 免提模式，实测说话出字

---

## 贡献

欢迎提 Issue 或 PR。

改规则时注意两点：

- `rules/*.json` 的顶层只能是 `title` 和 `rules`，不要加别的字段——Karabiner 的资源 schema 是严格的，多余字段会导致导入校验失败
- `install.sh` 里内嵌了生成同样 JSON 的 Python 逻辑，改完规则记得两边一起改，保持语义一致

---

## 许可

[MIT](LICENSE)
