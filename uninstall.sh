#!/usr/bin/env bash
# Remove voice-dictation-wayland. Models are kept unless --purge is given.
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
PURGE=0
[[ "${1:-}" == "--purge" ]] && PURGE=1

log() { printf '\033[1;33m[uninstall]\033[0m %s\n' "$*"; }

rm -f "$PREFIX/bin/voice-dictation"
log "已删除 $PREFIX/bin/voice-dictation"

if command -v gsettings >/dev/null 2>&1; then
    base=org.gnome.settings-daemon.plugins.media-keys
    current="$(gsettings get $base custom-keybindings 2>/dev/null || echo '[]')"
    paths="$(python3 - "$current" <<'PY'
import ast, sys
try:
    items = ast.literal_eval(sys.argv[1])
except Exception:
    items = []
items = [p for p in items if not p.startswith("/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-dictation")]
print("[" + ", ".join("'%s'" % p for p in items) + "]")
PY
)"
    gsettings set $base custom-keybindings "$paths" 2>/dev/null || true
    log "已移除 GNOME 快捷键"
fi

systemctl --user disable --now ydotool 2>/dev/null || true

if [[ $PURGE -eq 1 ]]; then
    rm -rf "$DATA_HOME/voice-input"
    log "已删除模型和配置：$DATA_HOME/voice-input"
else
    log "模型保留在 $DATA_HOME/voice-input（加 --purge 一并删除）"
fi

log "完成。ydotool/sherpa-onnx 软件包未自动卸载。"
