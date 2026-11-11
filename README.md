# voice-dictation-wayland

**Wayland 下的离线中文语音输入**：按一次快捷键开始录音，说完再按一次，识别结果直接粘贴到当前焦点窗口。

不切换输入法、不需要联网（模型下载完成后）、不依赖桌面环境特有的虚拟键盘协议。

```
ffmpeg (PipeWire) → Silero VAD → SenseVoice (sherpa-onnx) → 剪贴板 + ydotool 粘贴
```

## 特性

- **纯离线**：SenseVoice int8 模型，中/英/日/韩/粤语，中文自带标点与数字规范化
- **快**：Meteor Lake CPU 上 5.6 秒音频约 0.23 秒识别完（RTF ≈ 0.04）
- **抗噪**：Silero VAD 先过滤静音和环境噪声，不会把幻听文字粘出去
- **不碰输入法**：ibus-rime / fcitx5 照常使用，语音结果是直接提交的文本
- **任何应用可用**：GNOME Wayland 下通过 uinput 注入，浏览器、编辑器、终端都行
- **按一下就录，再按一下结束**：不需要一直按住

在 Arch Linux + GNOME 51 Wayland + ibus-rime 上开发和测试。其他 Wayland 桌面（Niri、Hyprland 等）理论上可用，需要有 `ydotoold` 和通知服务。

## 安装

### Arch Linux（自动）

```bash
git clone https://github.com/Moxin1044/voice-dictation-wayland.git
cd voice-dictation-wayland
./install.sh
```

安装脚本会：

1. 用 pacman 安装 `ydotool`、`wl-clipboard`、`libnotify`、`ffmpeg`
2. 用 yay/paru 安装 AUR 包 `sherpa-onnx-bin`
3. 下载模型到 `~/.local/share/voice-input/models`（约 230 MB）
4. 启用 `ydotool.service` 用户服务
5. 在 GNOME 中注册两个快捷键

可选参数：`--skip-deps`、`--skip-model`、`--skip-shortcut`。

### 手动安装（其他发行版）

依赖：`sherpa-onnx`（需包含 `sherpa-onnx-vad-with-offline-asr`）、`ydotool`、`wl-clipboard`、`libnotify`、`ffmpeg`、Python 3.9+。

```bash
install -Dm755 bin/voice-dictation ~/.local/bin/voice-dictation
./scripts/download-model.sh
systemctl --user enable --now ydotool
```

然后把桌面环境的全局快捷键绑定到：

- `voice-dictation`（普通应用）
- `voice-dictation --paste=ctrl-shift-v`（终端）

## 使用

| 快捷键 | 场景 | 上屏方式 |
|---|---|---|
| `Super+Alt+V` | 普通应用 | `Ctrl+V` |
| `Super+Alt+Shift+V` | 终端类应用 | `Ctrl+Shift+V` |

1. 按一下 → 通知「🎤 录音中…」
2. 说话
3. 再按一下 → 「⏳ 识别中…」→ 自动粘贴，并提示「✅ 已输入」

测试识别（不粘贴）：

```bash
voice-dictation --file ~/.local/share/voice-input/models/sense-voice/test_zh.wav --dry-run
# 开饭时间早上9点至下午5点。
```

### 命令行参数

```
--file PATH        识别指定 wav，不录音
--dry-run          只打印结果，不粘贴
--stop             结束当前录音
--paste MODE       ctrl-v | ctrl-shift-v | none
--version
```

### 环境变量

| 变量 | 默认值 | 说明 |
|---|---|---|
| `VOICE_MODEL_DIR` | `~/.local/share/voice-input/models/sense-voice` | ASR 模型目录 |
| `VOICE_VAD_MODEL` | `~/.local/share/voice-input/models/vad/silero_vad.onnx` | Silero VAD |
| `VOICE_PASTE_MODE` | `ctrl-v` | 默认粘贴方式 |
| `VOICE_MAX_SECONDS` | `120` | 单次录音上限 |
| `VOICE_THREADS` | `4` | onnxruntime 线程数 |

## 模型

| 文件 | 大小 | 来源 |
|---|---|---|
| `model.int8.onnx` | 229 MB | [sherpa-onnx 转换的 SenseVoiceSmall](https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17) |
| `tokens.txt` | 309 KB | 同上 |
| `silero_vad.onnx` | 629 KB | [sherpa-onnx VAD 模型](https://github.com/k2-fsa/sherpa-onnx/releases/tag/asr-models) |

`scripts/download-model.sh` 会优先从本仓库的 GitHub Release 下载，失败时回退到 HuggingFace；
可用 `HF_ENDPOINT=https://hf-mirror.com` 使用镜像。所有文件下载后都会校验 SHA-256。
模型也可以直接从 [Release 页面](https://github.com/Moxin1044/voice-dictation-wayland/releases) 手动下载。

## 卸载

```bash
./uninstall.sh          # 保留模型
./uninstall.sh --purge  # 连同模型一起删除
```

## 常见问题

**终端里没粘贴？** 终端一般用 `Ctrl+Shift+V`，请使用第二个快捷键，或加 `--paste=ctrl-shift-v`。

**提示没有检测到说话声？** VAD 过滤掉了静音/噪声。确认 `pactl get-default-source` 是正确的麦克风，并检查输入音量。

**快捷键冲突？** 在 GNOME 设置 → 键盘 → 自定义快捷键里修改。

**剪贴板被覆盖？** 上屏方式就是「写入剪贴板 + 模拟粘贴」，这是 Wayland 下不依赖输入法协议的通用做法。

**和 fcitx5-vinput 有什么区别？** `fcitx5-vinput` 是 fcitx5 插件，文字经过输入法上屏，体验更原生，但要求使用 fcitx5，且 GNOME 下要替换掉 IBus。本项目不改动输入法，适用于 IBus/Rime 或任何桌面。

## 致谢

- [sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx)（Apache-2.0）：推理框架
- [FunAudioLLM/SenseVoice](https://github.com/FunAudioLLM/SenseVoice)（MIT）：语音识别模型
- [Silero VAD](https://github.com/snakers4/silero-vad)（MIT）：语音活动检测
- [ydotool](https://github.com/ReimuNotMoe/ydotool)（AGPL-3.0）：Wayland 按键注入

本项目只做流程编排与桌面集成，识别能力来自上述项目。

## License

[MIT](LICENSE) © 2026 Moxin1044

---

## English

Offline Chinese push-to-talk dictation for Wayland. Press a hotkey to record, press again to
stop; the transcript is pasted into the focused window. Powered by sherpa-onnx + SenseVoice +
Silero VAD, typed via ydotool. No input-method changes, no network after model download.

```bash
git clone https://github.com/Moxin1044/voice-dictation-wayland.git
cd voice-dictation-wayland && ./install.sh
```

Hotkeys: `Super+Alt+V` (normal apps), `Super+Alt+Shift+V` (terminals).
