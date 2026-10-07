#!/bin/bash
# =============================================================================
# zarco-x11-dictation — setup-dictation.sh
# Instala e configura ditado por voz no Ubuntu X11 (atalho CTRL+Alt+X)
# Usa: whisper.cpp (offline) + arecord + xclip + xdotool, controlados por Ruby
#
# IMPORTANTE: Faça login com a sessão "Ubuntu" (Xorg), NÃO "Ubuntu com Wayland".
# Na tela de login, clique no ícone ⚙️ e selecione "Ubuntu" antes de entrar.
# =============================================================================

set -e

SCRIPT_DIR="$HOME/.local/bin"
WHISPER_DIR="$HOME/.local/share/whisper.cpp"
WHISPER_VERSION="v1.9.4"
MODEL="small"
REPO_RAW="https://raw.githubusercontent.com/felipezarco/zarco-x11-dictation/main"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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

    # Remove PPAs problemáticos que não suportam Ubuntu Noble
    if ls /etc/apt/sources.list.d/*gnome3* &>/dev/null; then
        info "Removendo PPA gnome3-team incompatível..."
        sudo rm -f /etc/apt/sources.list.d/*gnome3*
    fi

    # Atualiza repositórios (suprime erros de PPAs antigos)
    sudo apt-get update -qq 2>&1 | grep -v "ppa.launchpadcontent.net" | grep -v "não tem um arquivo Release" || true

    sudo apt-get install -y \
        ruby \
        alsa-utils \
        xdotool \
        xclip \
        x11-utils \
        libnotify-bin \
        git \
        cmake \
        build-essential \
        curl \
        2>/dev/null

    info "Dependências instaladas."
}

# =============================================================================
# 2. REMOVE A VERSÃO ANTIGA (bash + faster-whisper)
# =============================================================================
remove_legacy() {
    if [ -d "$HOME/.dictation" ] || [ -f "$SCRIPT_DIR/dictation-transcribe.py" ]; then
        info "Removendo a versão antiga com faster-whisper..."
        rm -f "$SCRIPT_DIR/dictation-start" "$SCRIPT_DIR/dictation-stop" "$SCRIPT_DIR/dictation-transcribe.py"
        rm -rf "$HOME/.dictation"
    fi
}

# =============================================================================
# 3. WHISPER.CPP
# =============================================================================
install_whisper() {
    if [ ! -d "$WHISPER_DIR/.git" ]; then
        info "Baixando whisper.cpp $WHISPER_VERSION em $WHISPER_DIR ..."
        git clone --depth 1 --branch "$WHISPER_VERSION" https://github.com/ggml-org/whisper.cpp.git "$WHISPER_DIR"
    fi

    info "Compilando whisper-cli (pode demorar alguns minutos)..."
    cmake -S "$WHISPER_DIR" -B "$WHISPER_DIR/build" -DCMAKE_BUILD_TYPE=Release > /dev/null
    cmake --build "$WHISPER_DIR/build" --config Release -j "$(nproc)" --target whisper-cli > /dev/null
    info "whisper-cli compilado."
}

# =============================================================================
# 4. MODELO DO WHISPER
# =============================================================================
download_model() {
    if [ -f "$WHISPER_DIR/models/ggml-$MODEL.bin" ]; then
        info "Modelo '$MODEL' já baixado."
        return
    fi

    info "Baixando modelo Whisper '$MODEL' (~466MB na primeira vez)..."
    sh "$WHISPER_DIR/models/download-ggml-model.sh" "$MODEL" "$WHISPER_DIR/models"
    info "Modelo pronto."
}

# =============================================================================
# 5. SCRIPT DE DITADO (chamado pelo atalho)
# =============================================================================
install_toggle() {
    info "Instalando dictation-toggle em $SCRIPT_DIR ..."
    mkdir -p "$SCRIPT_DIR"

    # Rodando do clone usa o arquivo local; baixado só o setup, busca no GitHub
    if [ -f "$HERE/dictation-toggle" ]; then
        install -m 755 "$HERE/dictation-toggle" "$SCRIPT_DIR/dictation-toggle"
    else
        curl -fsSL "$REPO_RAW/dictation-toggle" -o "$SCRIPT_DIR/dictation-toggle"
        chmod +x "$SCRIPT_DIR/dictation-toggle"
    fi

    info "dictation-toggle instalado."
}

# =============================================================================
# 6. ATALHO CTRL+Alt+X NO GNOME
# =============================================================================
register_shortcut() {
    info "Registrando atalho CTRL+Alt+X no GNOME..."

    SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
    BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/dictation/"

    # Acrescenta o atalho do ditado sem apagar os outros atalhos customizados
    EXISTING=$(gsettings get $SCHEMA custom-keybindings 2>/dev/null || echo "@as []")

    if echo "$EXISTING" | grep -q "$BASE"; then
        warning "Atalho de ditado já registrado, atualizando..."
    elif echo "$EXISTING" | grep -q "'"; then
        gsettings set $SCHEMA custom-keybindings "${EXISTING%]}, '${BASE}']"
    else
        gsettings set $SCHEMA custom-keybindings "['${BASE}']"
    fi

    gsettings set "${SCHEMA}.custom-keybinding:${BASE}" name    "Ditado por Voz"
    gsettings set "${SCHEMA}.custom-keybinding:${BASE}" command "$SCRIPT_DIR/dictation-toggle"
    gsettings set "${SCHEMA}.custom-keybinding:${BASE}" binding "<Control><Alt>x"

    info "Atalho CTRL+Alt+X configurado!"
    warning "Se o atalho não funcionar de imediato, faça logout/login."
}

# =============================================================================
# MAIN
# =============================================================================
echo ""
echo "============================================"
echo "  zarco-x11-dictation — Ditado por Voz     "
echo "  Requer login com Ubuntu (Xorg)!           "
echo "============================================"
echo ""

install_dependencies
remove_legacy
install_whisper
download_model
install_toggle
register_shortcut

echo ""
echo "============================================"
echo -e "${GREEN}  Instalação concluída!${NC}"
echo "============================================"
echo ""
echo "  Como usar:"
echo "  - Pressione CTRL+Alt+X para INICIAR a gravação"
echo "  - Fale o que quiser"
echo "  - Pressione CTRL+Alt+X novamente para PARAR e colar o texto"
echo "  - Esquecida ligada, a gravação para sozinha após 10 min sem fala"
echo ""
echo "  Para trocar idioma, modelo ou o tempo de silêncio, edite as"
echo "  constantes no topo de $SCRIPT_DIR/dictation-toggle"
echo ""
echo "  Modelos disponíveis: tiny | base | small | medium | large-v3"
echo "  (quanto maior, mais preciso e mais lento)"
echo "============================================"
echo ""
