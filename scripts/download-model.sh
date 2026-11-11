#!/usr/bin/env bash
# Download the offline ASR + VAD models used by voice-dictation-wayland.
set -euo pipefail

DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
MODEL_ROOT="${VOICE_MODEL_ROOT:-$DATA_HOME/voice-input/models}"
HF_ENDPOINT="${HF_ENDPOINT:-https://huggingface.co}"
VERSION="1.0.0"

# Upstream: sherpa-onnx conversion of FunAudioLLM/SenseVoiceSmall (MIT).
SENSE_VOICE_REPO="csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
HF_BASE="$HF_ENDPOINT/$SENSE_VOICE_REPO/resolve/main"
RELEASE_BASE="https://github.com/Moxin1044/voice-dictation-wayland/releases/download/v$VERSION"
SENSE_VOICE_DIR="$MODEL_ROOT/sense-voice"
VAD_DIR="$MODEL_ROOT/vad"

MODEL_SHA256="c71f0ce00bec95b07744e116345e33d8cbbe08cef896382cf907bf4b51a2cd51"
TOKENS_SHA256="f449eb28dc567533d7fa59be34e2abca8784f771850c78a47fb731a31429a1dc"
VAD_SHA256="9e2449e1087496d8d4caba907f23e0bd3f78d91fa552479bb9c23ac09cbb1fd6"
TEST_SHA256="b77f1794fe374a0ba1ee1dc458bfaf9349496cbbfc32780c50ba3c5a7ad8e373"

log() { printf '\033[1;34m[models]\033[0m %s\n' "$*"; }

fetch() { # fetch <url> <out> <sha256>
    local url="$1" out="$2" sha="$3"
    if [[ -f "$out" ]] && echo "$sha  $out" | sha256sum -c --status -; then
        log "已存在 $(basename "$out")"
        return 0
    fi
    mkdir -p "$(dirname "$out")"
    log "下载 $(basename "$out") ← ${url%%\?*}"
    rm -f "$out.part"
    if ! curl -fL --retry 3 --retry-delay 2 -o "$out.part" "$url"; then
        rm -f "$out.part"
        return 1
    fi
    mv "$out.part" "$out"
    if ! echo "$sha  $out" | sha256sum -c --status -; then
        echo "voice-dictation: 校验失败 $out" >&2
        rm -f "$out"
        return 1
    fi
}

first_of() { # first_of <dest> <sha> <url>...
    local out="$1" sha="$2"; shift 2
    local url
    for url in "$@"; do
        fetch "$url" "$out" "$sha" && return 0
        log "该源失败，换下一个源"
    done
    return 1
}

log "模型目录：$MODEL_ROOT"
mkdir -p "$SENSE_VOICE_DIR" "$VAD_DIR"

first_of "$SENSE_VOICE_DIR/model.int8.onnx" "$MODEL_SHA256" \
    "$RELEASE_BASE/model.int8.onnx" \
    "$HF_BASE/model.int8.onnx"

first_of "$SENSE_VOICE_DIR/tokens.txt" "$TOKENS_SHA256" \
    "$RELEASE_BASE/tokens.txt" \
    "$HF_BASE/tokens.txt"

first_of "$VAD_DIR/silero_vad.onnx" "$VAD_SHA256" \
    "$RELEASE_BASE/silero_vad.onnx" \
    "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/silero_vad.onnx"

# Optional sample audio for a smoke test; failures are non-fatal.
first_of "$SENSE_VOICE_DIR/test_zh.wav" "$TEST_SHA256" \
    "$RELEASE_BASE/test_zh.wav" \
    "$HF_BASE/test_wavs/zh.wav" || true

log "完成。测试：voice-dictation --file $SENSE_VOICE_DIR/test_zh.wav --dry-run"
