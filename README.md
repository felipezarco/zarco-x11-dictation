# zarco-x11-dictation

[![License: MIT](https://img.shields.io/badge/license-MIT-blue?style=flat-square)](LICENSE.md)
[![Platform](https://img.shields.io/badge/platform-Ubuntu%20X11-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com)
[![Session](https://img.shields.io/badge/session-Xorg%20only-informational?style=flat-square)](https://www.x.org)
[![Offline](https://img.shields.io/badge/mode-100%25%20offline-success?style=flat-square)](https://github.com/SYSTRAN/faster-whisper)
[![Powered by Whisper](https://img.shields.io/badge/powered%20by-faster--whisper-blueviolet?style=flat-square)](https://github.com/SYSTRAN/faster-whisper)
[![Stars](https://img.shields.io/github/stars/felipezarco/zarco-x11-dictation?style=flat-square)](https://github.com/felipezarco/zarco-x11-dictation/stargazers)

## Why type? I just talk to my machine now. 
Perfect Ubuntu (Xorg) offline dictation with a single keyboard shortcut.

I got tired of switching context to type every little thing. So I built this: I press a shortcut, say what I want, press it again — and the text appears wherever my cursor is. No cloud, no account, no subscription. 100% offline. Just my voice and my machine.

Press **CTRL+Alt+X** to start recording, say what you want, press **CTRL+Alt+X** again and the text is automatically typed wherever your cursor is — in any application.

<img width="1231" height="727" alt="image" src="https://github.com/user-attachments/assets/b08c9252-fa74-466a-95b0-1ead88aa5943" />

---

## ⚠️ Essential Requirement: Log in with Ubuntu (Xorg)

On the Ubuntu login screen, click the gear icon ⚙️ and select **"Ubuntu"** — **not "Ubuntu on Wayland"**.

> `xdotool` (responsible for typing text into windows) **does not work on Wayland**.
> If you skip this step, transcription will still work, but no text will be inserted.

```
Login screen → click ⚙️ → select "Ubuntu" (Xorg) → log in
```

---

## Install

### Option 1

Download it directly to your home directory and run:

```bash
curl -fsSL https://raw.githubusercontent.com/felipezarco/zarco-x11-dictation/main/setup-dictation.sh -o ~/setup-dictation.sh
chmod +x ~/setup-dictation.sh && ~/setup-dictation.sh
```

### Option 2

Clone the repository and run the setup script:

```bash
git clone https://github.com/felipezarco/zarco-x11-dictation.git
cd zarco-x11-dictation
chmod +x setup-dictation.sh && ./setup-dictation.sh
```

The script installs dependencies, sets up the Python environment with [faster-whisper](https://github.com/SYSTRAN/faster-whisper), downloads the voice model (~244MB), and registers the **CTRL+Alt+X** shortcut in GNOME automatically.

## Usage

| Action | Result |
|---|---|
| **CTRL+Alt+X** (1st press) | Starts recording |
| Speak normally | — |
| **CTRL+Alt+X** (2nd press) | Transcribes and types the text where your cursor is |

Works in any text field: terminal, VS Code, browser, editor, etc.

## How it works

- **[faster-whisper](https://github.com/SYSTRAN/faster-whisper)** — offline transcription using OpenAI's Whisper models
- **arecord** — captures microphone audio via ALSA
- **xdotool** — simulates typing in the active window (X11)

## Customization

To change the Whisper model, edit `~/.local/bin/dictation-transcribe.py`:

```python
model = WhisperModel("small", device="cpu", compute_type="int8")
#                     ^^^^^
#  tiny | base | small (default) | medium | large-v3
```

To change the language, update `language="pt"` on the same line.

To change the keyboard shortcut, go to **Settings → Keyboard → Keyboard Shortcuts → Custom Shortcuts**.

## Uninstall

```bash
rm -f ~/.local/bin/dictation-start \
      ~/.local/bin/dictation-stop \
      ~/.local/bin/dictation-toggle \
      ~/.local/bin/dictation-transcribe.py
rm -rf ~/.dictation
gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "[]"
```

---

If this worked for you, please leave a ⭐ on the repository!

## Author

Luiz Felipe Zarco (felipezarco@hotmail.com)

## License

This code is licensed under the [MIT License](LICENSE.md).

---

## Donate

If you find this project useful, consider supporting its development:

[![Donate with PayPal](https://www.paypalobjects.com/en_US/i/btn/btn_donate_SM.gif)](https://www.paypal.com/donate?hosted_button_id=A4SYWHDBRXLQC)
