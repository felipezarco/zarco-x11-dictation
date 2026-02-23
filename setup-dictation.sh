#!/bin/bash
# =============================================================================
# zarco-x11-dictate — setup-dictation.sh
# Instala e configura ditado por voz no Ubuntu X11 (atalho CTRL+`)
# Usa: faster-whisper (offline) + xdotool + arecord
#
# IMPORTANTE: Faça login com a sessão "Ubuntu" (Xorg), NÃO "Ubuntu com Wayland".
# Na tela de login, clique no ícone ⚙️ e selecione "Ubuntu" antes de entrar.
# =============================================================================

set -e

VENV_DIR="$HOME/.dictation"
SCRIPT_DIR="$HOME/.local/bin"
AUDIO_FILE="/tmp/dictation_audio.wav"
PID_FILE="/tmp/dictation.pid"

# Cores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# =============================================================================
# 1. DEPENDÊNCIAS DO SISTEMA
# =============================================================================
install_dependencies() {
    info "Instalando dependências do sistema..."
    sudo apt-get update -qq
    sudo apt-get install -y \
        python3 \
        python3-pip \
        python3-venv \
        xdotool \
        alsa-utils \
        ffmpeg \
        libnotify-bin \
        2>/dev/null

    info "Dependências instaladas."
}

# =============================================================================
# 2. AMBIENTE PYTHON + faster-whisper
# =============================================================================
install_python_env() {
    info "Criando ambiente Python em $VENV_DIR ..."
    python3 -m venv "$VENV_DIR"
    "$VENV_DIR/bin/pip" install --upgrade pip -q
    info "Instalando faster-whisper (pode demorar na primeira vez)..."
    "$VENV_DIR/bin/pip" install faster-whisper -q
    info "faster-whisper instalado."
}

# =============================================================================
# 3. SCRIPT DE TRANSCRIÇÃO
# =============================================================================
create_transcribe_script() {
    info "Criando script de transcrição..."
    mkdir -p "$SCRIPT_DIR"

    cat > "$SCRIPT_DIR/dictation-transcribe.py" << 'PYEOF'
#!/usr/bin/env python3
import sys
from faster_whisper import WhisperModel

audio_file = sys.argv[1] if len(sys.argv) > 1 else "/tmp/dictation_audio.wav"

# "small" é um bom equilíbrio entre velocidade e precisão em PT
# Troque por "tiny" se quiser mais velocidade, ou "medium" para mais precisão
model = WhisperModel("small", device="cpu", compute_type="int8")

segments, info = model.transcribe(audio_file, beam_size=5, language="pt")

text = " ".join(seg.text.strip() for seg in segments)
print(text, end="")
PYEOF

    chmod +x "$SCRIPT_DIR/dictation-transcribe.py"
    info "Script de transcrição criado."
}

# =============================================================================
# 4. SCRIPTS DE CONTROLE (start / stop / toggle)
# =============================================================================
create_control_scripts() {
    info "Criando scripts de controle..."

    # --- dictation-start ---
    cat > "$SCRIPT_DIR/dictation-start" << STARTEOF
#!/bin/bash
AUDIO_FILE="$AUDIO_FILE"
PID_FILE="$PID_FILE"
VENV_DIR="$VENV_DIR"

# Já está gravando?
if [ -f "\$PID_FILE" ]; then
    notify-send -i microphone "Ditado" "Já está gravando..." -t 1500
    exit 0
fi

notify-send -i microphone "Ditado" "🎙️ Gravando... (CTRL+\` para parar)" -t 2000

# Grava até receber sinal
arecord -f cd -r 16000 -c 1 -t wav "\$AUDIO_FILE" -q &
echo \$! > "\$PID_FILE"
STARTEOF

    # --- dictation-stop ---
    cat > "$SCRIPT_DIR/dictation-stop" << STOPEOF
#!/bin/bash
AUDIO_FILE="$AUDIO_FILE"
PID_FILE="$PID_FILE"
VENV_DIR="$VENV_DIR"
TRANSCRIBE_SCRIPT="$SCRIPT_DIR/dictation-transcribe.py"

if [ ! -f "\$PID_FILE" ]; then
    notify-send -i dialog-warning "Ditado" "Nenhuma gravação ativa." -t 1500
    exit 0
fi

# Para a gravação
kill \$(cat "\$PID_FILE") 2>/dev/null
rm -f "\$PID_FILE"
sleep 0.3

notify-send -i system-search "Ditado" "⏳ Transcrevendo..." -t 3000

# Transcreve
TEXT=\$("\$VENV_DIR/bin/python3" "\$TRANSCRIBE_SCRIPT" "\$AUDIO_FILE" 2>/dev/null)

if [ -n "\$TEXT" ]; then
    # Remove espaço inicial se houver
    TEXT=\$(echo "\$TEXT" | sed 's/^ *//')
    # Digita o texto na janela ativa
    xdotool type --clearmodifiers --delay 20 -- "\$TEXT"
    notify-send -i emblem-default "Ditado" "✅ \$TEXT" -t 3000
else
    notify-send -i dialog-error "Ditado" "❌ Nenhum texto detectado." -t 2000
fi

rm -f "\$AUDIO_FILE"
STOPEOF

    # --- dictation-toggle (chamado pelo atalho) ---
    cat > "$SCRIPT_DIR/dictation-toggle" << TOGGLEEOF
#!/bin/bash
PID_FILE="$PID_FILE"

if [ -f "\$PID_FILE" ]; then
    "$SCRIPT_DIR/dictation-stop"
else
    "$SCRIPT_DIR/dictation-start"
fi
TOGGLEEOF

    chmod +x "$SCRIPT_DIR/dictation-start"
    chmod +x "$SCRIPT_DIR/dictation-stop"
    chmod +x "$SCRIPT_DIR/dictation-toggle"

    info "Scripts de controle criados em $SCRIPT_DIR."
}

# =============================================================================
# 5. ATALHO CTRL+F12 NO GNOME
# =============================================================================
register_shortcut() {
    info "Registrando atalho CTRL+F12 no GNOME..."

    SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
    BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/dictation/"

    # Verifica se já existe outro atalho customizado para não sobrescrever
    EXISTING=$(gsettings get $SCHEMA custom-keybindings 2>/dev/null || echo "@as []")

    if echo "$EXISTING" | grep -q "dictation"; then
        warning "Atalho de ditado já registrado, atualizando..."
    fi

    gsettings set $SCHEMA custom-keybindings "['${BASE}']"
    gsettings set "${SCHEMA}.custom-keybinding:${BASE}" name    "Ditado por Voz"
    gsettings set "${SCHEMA}.custom-keybinding:${BASE}" command "$SCRIPT_DIR/dictation-toggle"
    gsettings set "${SCHEMA}.custom-keybinding:${BASE}" binding "<Control>grave"

    info "Atalho CTRL+\` configurado!"
    warning "Se o atalho não funcionar de imediato, faça logout/login."
}

# =============================================================================
# 6. PRÉ-AQUECIMENTO DO MODELO (baixa o modelo Whisper na primeira vez)
# =============================================================================
warmup_model() {
    info "Baixando modelo Whisper 'small' (primeira vez ~244MB)..."
    info "Isso pode demorar alguns minutos..."
    "$VENV_DIR/bin/python3" -c "
from faster_whisper import WhisperModel
print('Baixando modelo...')
WhisperModel('small', device='cpu', compute_type='int8')
print('Modelo pronto!')
"
    info "Modelo carregado e em cache."
}

# =============================================================================
# MAIN
# =============================================================================
echo ""
echo "============================================"
echo "  zarco-x11-dictate — Ditado por Voz       "
echo "  Requer login com Ubuntu (Xorg)!           "
echo "============================================"
echo ""

install_dependencies
install_python_env
create_transcribe_script
create_control_scripts
warmup_model
register_shortcut

echo ""
echo "============================================"
echo -e "${GREEN}  Instalação concluída!${NC}"
echo "============================================"
echo ""
echo "  Como usar:"
echo "  → Pressione CTRL+\` para INICIAR a gravação"
echo "  → Fale o que quiser"
echo "  → Pressione CTRL+\` novamente para PARAR e digitar"
echo ""
echo "  Para trocar o idioma ou modelo, edite:"
echo "  $SCRIPT_DIR/dictation-transcribe.py"
echo ""
echo "  Modelos disponíveis: tiny | base | small | medium | large-v3"
echo "  (quanto maior, mais preciso e mais lento)"
echo "============================================"
echo ""
