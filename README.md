# ClipDeck (Omarchy Shell Plugin)

[![Omarchy 4](https://img.shields.io/badge/Omarchy-4_(Quattro)-blue?style=flat-square)](https://omarchy.org/)
[![Plugin Release](https://img.shields.io/badge/plugin-v0.5.2-blueviolet?style=flat-square)](https://github.com/Mersad-Moghaddam/omarchy-clipdeck/releases/tag/v0.5.2)
[![Companion Daemon](https://img.shields.io/badge/companion-v0.5.2-success?style=flat-square)](https://github.com/Mersad-Moghaddam/clipdeck/releases/tag/v0.5.2)
[![Platform](https://img.shields.io/badge/platform-Wayland%20%7C%20X11-informational?style=flat-square)](https://github.com/Mersad-Moghaddam/clipdeck/blob/v0.5.2/docs/desktop-support.md)
[![License: MIT](https://img.shields.io/badge/license-MIT-green?style=flat-square)](LICENSE)

A keyboard-first clipboard manager plugin for [Omarchy](https://omarchy.org/) 4 (Quattro) and modern Linux desktops. Features persistent SQLite FTS5 search, split-pane inspectors, live syntax highlighting, Persian text and digit normalization, and dynamic Omarchy theme synchronization.

> [!IMPORTANT]
> **Architecture: Omarchy Shell Plugin + Pure-Go Daemon (`clipdeckd`)**
> - **On Omarchy:** The UI loads directly in `omarchy-shell` as a native QML overlay, adapting live to active Omarchy theme tokens (`Color.menu.*`, `Style.*`). It communicates with the companion daemon over a local Unix domain socket with UID verification.
> - **On other desktops:** use the standalone Qt popup (`clipdeck-ui`). Outside Omarchy it uses Qt's desktop palette and font, with normal window decorations. GTK theme matching depends on Qt platform-theme integration. Some shortcuts differ from the shell overlay below.

> [!TIP]
> ClipDeck is submitted to the [Omarchy community plugin marketplace](https://plugins.omarchy.org/). You can also install directly from this repository with the instructions below.

---

## Screenshots

![ClipDeck overlay — Berserk (dark)](screenshots/dark.png)

![ClipDeck overlay — Catppuccin Latte (light)](screenshots/light.png)

*The overlay builds entirely from Omarchy theme tokens. It restyles live on theme switches (`omarchy theme set ...`) with zero application restarts.*

---

## Features

- **Keyboard-First Workflow:** Summon instantly with `Super+V`. Navigate with arrow keys or `Ctrl+J`/`K`. Every action displays its shortcut inline, and keystrokes search immediately without a separate text input field.
- **Persistent & Sub-Millisecond Search:** Powered by `clipdeckd` and SQLite FTS5 trigram search for instant filtering across tens of thousands of clips.
- **Split-Pane Inspector:** Virtualized clip list on the left with item type badges, source application names, and timestamps. The right inspector inspects the active clip: clickable HEX/RGB/HSL color swatches, image previews with dimension tags, domain chips for URLs, and syntax-highlighted code.
- **Deep Content Classification:** Automatically detects plain text, source code (Go, Rust, Python, JavaScript, C++, HTML, Shell), JSON structures, colors, URLs, file paths, email addresses, and phone numbers.
- **Live Theme Synchronization:** The daemon stores raw content without hardcoding colors. The UI applies dynamic theme-derived styles on every render, keeping syntax highlighting legible in light and dark modes alike.
- **Privacy & Sensitive Data Protection:** Recognizes password manager hints (`x-kde-passwordManagerHint`), tokens, passwords, and private keys. Sensitive clips stay masked until revealed with `Ctrl+R` and show a countdown before automatic expiration.
- **Multi-Select & Merge:** Press `Space` to select clips, `Ctrl+A` to select all visible rows, and `Enter` to merge multiple items into a single clip with newline, space, or comma delimiters.
- **Quick Paste:** Press `Alt+1` through `Alt+9` to paste any of the first nine visible items immediately.
- **Persian & RTL Language Support:**
  - Automatic right-to-left layout alignment with adjusted line spacing.
  - Built-in transformations: Persian digits ⇄ Latin, Arabic yeh/kaf normalization, and zero-width non-joiner (ZWNJ / نیم‌فاصله) standardization.
- **Transformations Suite:** Convert case (UPPERCASE, lowercase, camelCase, snake_case), format JSON, encode/decode base64 and URLs, sort lines, and deduplicate with live previews before applying.
- **Compositor Paste Dispatcher:** Pastes directly into active Wayland windows (`wtype` / `hyprctl dispatch sendshortcut`) or copies cleanly to the system clipboard.
- **Omarchy Status Bar Widget:** Displays a live clip counter fed by daemon events, urgent color indicators during capture pause, and quick summon / pause toggles.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| <kbd>Enter</kbd> | Paste selected item into active window |
| <kbd>Shift</kbd>+<kbd>Enter</kbd> | Paste as plain text |
| <kbd>Ctrl</kbd>+<kbd>Enter</kbd> | Copy to clipboard only (no paste) |
| <kbd>Alt</kbd>+<kbd>Enter</kbd> | Open link, file path, or image in default app |
| <kbd>Ctrl</kbd>+<kbd>C</kbd> / <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> | Copy (or copy as plain text) |
| <kbd>Alt</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | Quick paste one of the first nine visible clips |
| <kbd>Space</kbd> / <kbd>Ctrl</kbd>+<kbd>Space</kbd> | Toggle multi-select checkbox |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> | Select all visible clips |
| <kbd>Enter</kbd> *(with 2+ selected)* | Merge selected clips and copy (<kbd>Shift</kbd>+<kbd>Enter</kbd> merges and pastes) |
| <kbd>Ctrl</kbd>+<kbd>P</kbd> | Toggle Pin / Unpin |
| <kbd>Ctrl</kbd>+<kbd>T</kbd> | Open Transform picker (live preview; Enter copies, Shift+Enter pastes) |
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | Reveal or mask sensitive clip preview |
| <kbd>Ctrl</kbd>+<kbd>I</kbd> | Toggle Incognito mode (pause clipboard capture) |
| <kbd>Delete</kbd> | Delete selected clip (<kbd>Shift</kbd>+<kbd>Delete</kbd> clears unpinned history) |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | Cycle categories (All, Pinned, Colors, Code, Links, Images, Text) |
| <kbd>↑</kbd>/<kbd>↓</kbd>/<kbd>PgUp</kbd>/<kbd>PgDn</kbd>/<kbd>Home</kbd>/<kbd>End</kbd> | Move navigation cursor (<kbd>Ctrl</kbd>+<kbd>J</kbd>/<kbd>K</kbd> supported) |
| <kbd>Backspace</kbd> / <kbd>Ctrl</kbd>+<kbd>U</kbd> | Backspace character / clear current search filter |
| <kbd>Esc</kbd> | Clear selection → clear filter → dismiss overlay |

---

## Installation

**Current release: plugin v0.5.2 + companion v0.5.2.** Both repositories publish
separate releases: this repository contains the Omarchy plugin; download daemon,
CLI and standalone GUI artifacts from the [companion release](https://github.com/Mersad-Moghaddam/clipdeck/releases/tag/v0.5.2).
This plugin release updates setup guidance and metadata, not the Omarchy overlay.

Jump to [Omarchy installation](#path-a-omarchy-4-users-hyprland) or
[standalone installation](#path-b-other-linux-distributions-standalone-app).

> [!WARNING]
> **Zorin / GNOME Wayland:** automatic clipboard capture is not supported by the current release.
> Installing `wl-clipboard` or `wtype` does not enable GNOME clipboard monitoring.
> Log out and select an Xorg/X11 session from the login screen. Install the X11
> dependencies in the [desktop setup guide](https://github.com/Mersad-Moghaddam/clipdeck/blob/main/docs/desktop-support.md).
> Native `.deb`, `.rpm`, and `.apk` packages contain the daemon and CLI, **not the Qt popup**.
> Use `--with-ui` for the standalone interface. Package availability does not mean
> every listed distribution or ARM64 environment has been run-tested.

Choose the setup matching your desktop environment:

### Path A: Omarchy 4 Users (Hyprland)

Follow these steps to install the companion daemon and register the Omarchy shell plugin.

#### Step 1: Install Companion Daemon (`clipdeckd`)

Install the pure-Go companion daemon using the checksummed user-local installer (**recommended**, no `sudo` required):

```bash
curl -fsSL https://raw.githubusercontent.com/Mersad-Moghaddam/clipdeck/v0.5.2/packaging/install.sh -o /tmp/clipdeck-install.sh &&
bash /tmp/clipdeck-install.sh --version 0.5.2 --daemon-only
```

*This installs `clipdeck` and `clipdeckd` into `~/.local/bin` and enables the systemd user service.*

#### Step 2: Install Shell Plugin

Add the plugin using the Omarchy CLI:

```bash
omarchy plugin add https://github.com/Mersad-Moghaddam/omarchy-clipdeck.git --enable
```

*Or install manually for development:*
```bash
git clone https://github.com/Mersad-Moghaddam/omarchy-clipdeck.git ~/.config/omarchy/plugins/io.github.mersadmoghaddam.clipdeck
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.mersadmoghaddam.clipdeck --section right
```

#### Step 3: Configure Hyprland Keybinding

Add this line to `~/.config/hypr/bindings.conf` or your Hyprland configuration:

```ini
bind = SUPER, V, exec, omarchy-shell shell toggle io.github.mersadmoghaddam.clipdeck '{}'
```

#### Step 4: Verify Installation

Run the health check suite to confirm clipboard utilities, socket communication, and database integrity:

```bash
clipdeck doctor
```

---

### Path B: Other Linux Distributions (Standalone App)

If you are running **Ubuntu, Debian, Fedora, Arch, Alpine, i3, or another desktop environment**, use the standalone companion app with its dedicated Qt popup.

#### 1. User-local installer (recommended)

Installs the daemon, CLI, and standalone GUI into `~/.local/bin` without root privileges:

```bash
curl -fsSL https://raw.githubusercontent.com/Mersad-Moghaddam/clipdeck/v0.5.2/packaging/install.sh -o /tmp/clipdeck-install.sh &&
bash /tmp/clipdeck-install.sh --version 0.5.2 --with-ui
```

*Requirements for `--with-ui`: Python 3.12+, `python3-venv`, and desktop Qt runtime libraries. On Ubuntu/Debian, install prerequisite packages first: `sudo apt install python3-venv xclip xdotool`.*

Launch the popup from your application launcher or by running:
```bash
clipdeck-ui
```

---

#### 2. Native Distribution Packages

Pre-built packages for **v0.5.2** are published on the [GitHub Releases page](https://github.com/Mersad-Moghaddam/clipdeck/releases/tag/v0.5.2). Each snippet below verifies SHA-256 integrity before installation.

##### Debian / Ubuntu / Linux Mint / Pop!_OS / Zorin OS (`.deb`)

```bash
# For amd64 (x86_64)
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/clipdeck_0.5.2_amd64.deb &&
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/SHA256SUMS &&
grep -E '  (\./)?clipdeck_0\.5\.2_amd64\.deb$' SHA256SUMS > package.sha256 &&
test -s package.sha256 && sha256sum -c package.sha256 &&
sudo apt install ./clipdeck_0.5.2_amd64.deb

# For arm64 (aarch64)
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/clipdeck_0.5.2_arm64.deb &&
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/SHA256SUMS &&
grep -E '  (\./)?clipdeck_0\.5\.2_arm64\.deb$' SHA256SUMS > package.sha256 &&
test -s package.sha256 && sha256sum -c package.sha256 &&
sudo apt install ./clipdeck_0.5.2_arm64.deb
```

##### Fedora / RHEL / Rocky Linux / AlmaLinux (`.rpm`)

```bash
# For x86_64
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/clipdeck-0.5.2-1.x86_64.rpm &&
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/SHA256SUMS &&
grep -E '  (\./)?clipdeck-0\.5\.2-1\.x86_64\.rpm$' SHA256SUMS > package.sha256 &&
test -s package.sha256 && sha256sum -c package.sha256 &&
sudo dnf install ./clipdeck-0.5.2-1.x86_64.rpm

# For aarch64 (ARM64)
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/clipdeck-0.5.2-1.aarch64.rpm &&
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/SHA256SUMS &&
grep -E '  (\./)?clipdeck-0\.5\.2-1\.aarch64\.rpm$' SHA256SUMS > package.sha256 &&
test -s package.sha256 && sha256sum -c package.sha256 &&
sudo dnf install ./clipdeck-0.5.2-1.aarch64.rpm
```

##### openSUSE (`.rpm`)

```bash
# Verify the RPM package using the Fedora block above, then install:
sudo zypper install ./clipdeck-0.5.2-1.x86_64.rpm
```

##### Arch Linux / Manjaro / EndeavourOS (`PKGBUILD`)

Build and install directly from the packaging recipe:

```bash
git clone https://github.com/Mersad-Moghaddam/clipdeck.git /tmp/clipdeck-build &&
cd /tmp/clipdeck-build/packaging/aur/clipdeck &&
makepkg -si
```

##### Alpine Linux (`.apk`)

```bash
# For x86_64
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/clipdeck_0.5.2_x86_64.apk &&
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.2/SHA256SUMS &&
grep -E '  (\./)?clipdeck_0\.5\.2_x86_64\.apk$' SHA256SUMS > package.sha256 &&
test -s package.sha256 && sha256sum -c package.sha256 &&
sudo apk add --allow-untrusted ./clipdeck_0.5.2_x86_64.apk
```

##### Generic Linux (Prebuilt Tarball)

Use the checksum-verifying installer above with `--daemon-only`. It validates
archive paths and installs the binaries safely. Do not extract unverified
archives directly into your executable directory.

---

### Desktop Integration & Autostart

- **Systemd User Service:** Distribution packages and the installer automatically install and register `clipdeckd.service`. To start manually:
  ```bash
  systemctl --user enable --now clipdeckd.service
  ```
- **In-App Activation:** If the daemon is not running when you open the Omarchy overlay, click **Start & enable at login** in the notice pane to activate the service immediately.
- **i3 / X11 Window Manager Setup:** Add floating and positioning rules to your `~/.config/i3/config`:
  ```ini
  for_window [class="clipdeck-ui"] floating enable, border pixel 2
  bindsym Mod4+v exec --no-startup-id clipdeck-ui
  ```

---

## Theming

ClipDeck integrates with Omarchy's design language by querying reactive system theme tokens:

- `Border.surfaceSpec("menu", "border", …)` applies menu card border width, corner radius, gradients, and opacity.
- `Color.menu.*` supplies background, text, scrim, and highlight accents.
- `Color.accent` and `Color.urgent` format interactive controls and destructive confirmations, dynamically mixed against your active palette.
- Highlighting classes (`t-keyword`, `t-string`, `t-comment`, `t-json-key`) map to theme tokens at render time.

When you switch themes (`omarchy theme set ...`), ClipDeck restyles instantaneously without restarting the process.

---

## Diagnostics & CLI Tools

ClipDeck includes a companion CLI for status checks, automated pipelines, and terminal workflows.

```bash
# Run comprehensive environment and dependency checks
clipdeck doctor

# Interactive terminal fuzzy picker (auto-detects fzf, rofi, wofi, or bemenu)
clipdeck pick

# Fuzzy picker with direct paste into the focused window
clipdeck pick --paste

# View stored clips from terminal
clipdeck history --limit 20
```

---

## Changelog

### 0.5.2

* Plugin release metadata and README now reference the public companion v0.5.2.
* Omarchy overlay code, theme integration and keyboard behavior are unchanged.
* Companion changes below ship in the separate daemon/standalone repository.

* Existing history directories are restricted to `0700`; private directory symlinks are rejected.
* Explicit systemd directory modes and actionable GNOME Wayland capture diagnostics.
* Standalone desktop palette/font selection and normal window decorations outside Omarchy.
* Native GNOME Wayland capture remains unsupported; use an Xorg/X11 session.

### 0.5.0
* **Standalone Desktop UI:** Shipped an independent Qt-based popup companion for non-Omarchy environments (Debian, Ubuntu, Fedora, Arch, Alpine, and i3/X11 desktops) with identical shortcuts, search speed, and Omarchy design tokens.
* **Companion Daemon v0.5.2:** Fixed search query and category filter persistence across popup reopenings while dynamically rebinding the active paste target.
* **Multi-Distribution Releases:** Automated prebuilt release artifacts for Debian/Ubuntu (`.deb`), Fedora/RHEL (`.rpm`), Alpine (`.apk`), Arch Linux (`PKGBUILD`), and portable tarballs for both `amd64` and `arm64`.
* **Zero-Root Universal Installer:** Introduced a guided user-local installer script (`install.sh`) supporting automated SHA-256 integrity checks, `--daemon-only`, and `--with-ui` workflows.
* **Storage & Permission Hardening:** Tightened data directory permissions to `0700`, added atomic database backup during migrations, and enforced safe transactional rollback on installation failure.
* **Diagnostics Suite:** Expanded `clipdeck doctor` to inspect wayland/x11 session state, compositor paste dispatcher availability, socket permissions, and database health.

### 0.4.3
* Imported image content now uses only the validated blob path, dropping symlink and missing-file content references.
* Companion blob writes reject unsafe extensions and non-regular cached targets, use exclusive random temporary files, and tolerate concurrent identical saves. Cached thumbnail symlinks are rejected too.
* Native systemd packages start at graphical login; the offline panel offers an explicit **Start & enable at login** action instead of copying a terminal command.
* Expanded filesystem and startup regression coverage. The companion remains a separately installed, manual-setup dependency.

### 0.4.2
* Companion security hardening: Enforces strict lexical path containment (`isManagedItemPath`) and `os.Lstat` regular file verification in the companion daemon's `SanitizeImportedItem` and `gcItemFile`. Completely neutralizes directory traversal (`..`), foreign path injection, and symlink attacks during history import, item deletion, clearing, and expiry GC.

### 0.4.1
* Zero-latency selection: Eliminated multi-pass regex theme transformations with ordered memoization in `DeckTheme.js`.
* Reactive inspector properties: Replaced imperative function re-evaluations with cached QML properties (`hasRichPreview`, `currentRichPreview`, `isPreviewRTL`), reducing large-clip selection latency from 1,068 ms to <70 ms (>93% speedup).
* Layout freeze guards: Capped rich code previews to 90 lines in the inspector and plain text viewports to 32 KB, preventing UI layout locks while preserving 100% untruncated content for copy/paste.
* Theme token correctness: Corrected row hover action background token from undefined `cardBg` to `bg`.

### 0.4.0
* Generation-guarded queries: Monotonic request tokens reject stale async query replies, eliminating list flickering during fast search typing.
* Pre-paged category filtering: Evaluates category filters and search queries server-side before pagination offsets, ensuring smooth scrolling and stable page boundaries.
* Guarded previews and bounded cache: Preview cache is bounded to 32 entries; sensitive items are never prefetched in the background without explicit reveal.
* Reliable paste fallback: Surfaces paste failure events with automatic user notification and safe clipboard fallback.

### 0.3.1
* Zero-lag hover quick actions: Single-area hit-tested action pill eliminates mouse jitter and layout thrashing.
* Full Persian & markdown preview: Dynamic `get` fetch for large/slimmed clips delivers 100% untruncated content in the inspector.
* RTL font & search polish: Restored system UI font for Persian text; right-aligned Persian search input with synchronized caret blinking.
* Micro-pill batch actions: Replaced bare text with tactile micro-pill buttons for multi-select Merge and Delete.

### 0.3.0
* Keyboard cursor re-anchors to the same clip across live reorders — Enter always pastes the row you are looking at, even when a capture lands mid-session.
* Unrevealed secrets can no longer leak through the transform picker (masked preview, transform requires Ctrl+R reveal).
* Merge-and-paste now hides the deck before dispatching the paste, like single paste.
* Pin/delete/merge failures surface as toasts; an optimistic pin rolls back when the daemon rejects it; deleted clips leave no ghost checkboxes; timed-out RPC calls fire their callbacks instead of hanging.
* Confirm dialogs preselect Cancel — muscle-memory Enter never wipes history.
* Search with no matches shows a clear-filter chip; empty history explains how capture and paste work.
* Hover quick-actions (Copy / Pin / ✕) and a batch Merge · Delete strip while multi-selecting; the inspector shows exact timestamps.
* Reliability: checkbox hit area fixed, external file:// passthrough, repaint on external pin changes, `json-number` syntax coloring, emoji never split mid-surrogate, bar socket falls back like the daemon when XDG_RUNTIME_DIR is unset.

### 0.2.0
* Initial marketplace release: list/search, keyboard-first paste, multi-select merge, pinned category, sensitive masking, transforms, color and image previews.

---

## License

MIT License. See [LICENSE](LICENSE) for details.
