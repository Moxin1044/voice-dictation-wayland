#!/usr/bin/env bash
# Installer for voice-dictation-wayland (Arch Linux / GNOME Wayland focus).
set -euo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"

SKIP_DEPS=0
SKIP_MODEL=0
SKIP_SHORTCUT=0

for arg in "$@"; do
    case "$arg" in
        --skip-deps) SKIP_DEPS=1 ;;
        --skip-model) SKIP_MODEL=1 ;;
        --skip-shortcut) SKIP_SHORTCUT=1 ;;
        -h|--help)
            sed -n '2,12p' "$0"
            exit 0
            ;;
        *) echo "未知参数：$arg" >&2; exit 1 ;;
    esac
done

log() { printf '\033[1;32m[install]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[warn]\033[0m %s\n' "$*"; }

need() { command -v "$1" >/dev/null 2>&1; }

if [[ $SKIP_DEPS -eq 0 ]]; then
    if need pacman; then
        mapfile -t missing_pkgs < <(for p in ydotool wl-clipboard libnotify ffmpeg; do
            pacman -Qq "$p" >/dev/null 2>&1 || echo "$p"; done)
        [[ ${#missing_pkgs[@]} -gt 0 ]] && sudo pacman -S --needed --noconfirm "${missing_pkgs[@]}"

        if ! need sherpa-onnx-offline; then
            if need yay; then
                yay -S --needed --noconfirm sherpa-onnx-bin
            elif need paru; then
                paru -S --needed --noconfirm sherpa-onnx-bin
            else
                warn "未找到 yay/paru，请手动安装 AUR 包 sherpa-onnx-bin"
            fi
        fi
    else
        warn "非 Arch 系统：请自行安装 ffmpeg、wl-clipboard、libnotify、ydotool、sherpa-onnx"
    fi
fi

log "安装脚本到 $BIN_DIR/voice-dictation"
mkdir -p "$BIN_DIR"
install -m 0755 "$REPO_DIR/bin/voice-dictation" "$BIN_DIR/voice-dictation"

if [[ $SKIP_MODEL -eq 0 ]]; then
    log "下载模型（约 230 MB）"
    bash "$REPO_DIR/scripts/download-model.sh"
fi

if need systemctl; then
    log "启用 ydotoold 用户服务"
    systemctl --user enable --now ydotool 2>/dev/null || warn "无法启用 ydotool.service，请确认已安装 ydotool"
fi

if [[ $SKIP_SHORTCUT -eq 0 ]] && need gsettings && [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    base=org.gnome.settings-daemon.plugins.media-keys
    p1=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-dictation/
    p2=/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-dictation-terminal/
    current="$(gsettings get $base custom-keybindings)"
    paths="$(python3 - "$current" "$p1" "$p2" <<'PY'
import ast, sys
try:
    items = ast.literal_eval(sys.argv[1])
except Exception:
    items = []
for path in sys.argv[2:]:
    if path not in items:
        items.append(path)
print("[" + ", ".join("'%s'" % p for p in items) + "]")
PY
)"
    gsettings set $base custom-keybindings "$paths"
    gsettings set $base.custom-keybinding:$p1 name '语音输入'
    gsettings set $base.custom-keybinding:$p1 command "$BIN_DIR/voice-dictation"
    gsettings set $base.custom-keybinding:$p1 binding '<Super><Alt>v'
    gsettings set $base.custom-keybinding:$p2 name '语音输入（终端）'
    gsettings set $base.custom-keybinding:$p2 command "$BIN_DIR/voice-dictation --paste=ctrl-shift-v"
    gsettings set $base.custom-keybinding:$p2 binding '<Super><Alt><Shift>v'
    log "已注册快捷键：Super+Alt+V / Super+Alt+Shift+V"
fi

cat <<EOF

安装完成。

  普通应用：Super+Alt+V       （Ctrl+V 上屏）
  终端应用：Super+Alt+Shift+V （Ctrl+Shift+V 上屏）
  测试：    $BIN_DIR/voice-dictation --file $DATA_HOME/voice-input/models/sense-voice/test_zh.wav --dry-run

首次使用前确认默认输入设备正确：pactl get-default-source
EOF
