# ClipDeck (Omarchy Shell Plugin)

A beautiful, keyboard-first clipboard manager plugin for [Omarchy](https://omarchy.org/) 4 (Quattro). Persistent history, real-time FTS5 search, rich inspectors, syntax-highlighted code, Persian text & digit tools, and Omarchy theme synchronization.

> [!IMPORTANT]
> **ClipDeck is an Omarchy shell plugin paired with a pure-Go daemon (`clipdeckd`).**
> The UI is loaded directly by `omarchy-shell`, adapts reactively to your active Omarchy theme tokens (`Color.menu.*`, `Style.*`), and communicates with `clipdeckd` over a high-performance Unix domain socket with UID verification.

> [!TIP]
> ClipDeck is submitted to the [Omarchy community plugin marketplace](https://plugins.omarchy.org/) — or install straight from this repository with the one-liner below.

---

## Features

- **Keyboard-First Experience:** Summon instantly via hotkey (`Super+V`), navigate with arrow keys (or Ctrl+J/K), and act with simple key combinations. Every action shows its shortcut inline, and there is no hidden text field — every keystroke searches.
- **Persistent & Fast:** Powered by `clipdeckd` and SQLite FTS5 trigram search — instant sub-millisecond retrieval across tens of thousands of clips.
- **Split-Pane Inspector:** Virtualized clip list on the left with type badges, source application, and freshness stamps. The right pane inspects the selected clip: color swatches with HEX/RGB/HSL rows that copy on click, image previews with dimensions, links with domain chips, code/JSON with themed syntax highlighting, and strict plain-text rendering for everything else.
- **Deep Content Detection:** Automatically classifies content as plain text, code (Go, Rust, Python, JS, C++, HTML, Shell), JSON, colors (HEX, RGB, HSL), links, file paths, emails, and phone numbers.
- **Live Theme Synchronization:** The daemon never bakes colors into stored previews — it emits class-based markup that the overlay re-colors from the active Omarchy palette on every render. Theme switches apply instantly, and highlighting can never clash with (or override) your theme.
- **Sensitive Data & Expiry:** Detects password manager hints (`x-kde-passwordManagerHint`), tokens, keys, and credentials. Sensitive clips stay masked in the inspector until you press `Ctrl+R`, and show a live TTL countdown when they expire.
- **Multi-Select & Merge:** `Space` toggles selection, `Ctrl+A` selects everything visible, and `Enter` merges the selection into one clip (newline, space, or comma separators) and copies it.
- **Quick Paste:** `Alt+1..9` pastes one of the first nine visible clips immediately.
- **Persian & RTL Language Support:**
  - Automatic right-to-left rendering with Persian-friendly line height.
  - One-click transformations: Persian digits ⇄ Latin, Arabic yeh/kaf normalization, ZWNJ (نیم‌فاصله) standardization.
- **Transformations Suite:** UPPERCASE, lowercase, camelCase, snake_case, JSON formatting, base64 encode/decode, URL encode/decode, line sorting, and deduplication — with a live preview before you apply.
- **Direct Paste Dispatcher:** Paste directly into active Wayland windows (`wtype` / `hyprctl dispatch sendshortcut`) or copy to the system clipboard.
- **Status Bar Widget:** Live clip counter fed by daemon events, urgent tint while capture is paused, and a tooltip that spells out the state. Left click summons the deck; middle/right click toggles pause.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| <kbd>Enter</kbd> | Paste selected item into active window |
| <kbd>Shift</kbd>+<kbd>Enter</kbd> | Paste as plain text |
| <kbd>Ctrl</kbd>+<kbd>Enter</kbd> | Copy only (no paste) |
| <kbd>Alt</kbd>+<kbd>Enter</kbd> | Open link/image/path with the default app |
| <kbd>Ctrl</kbd>+<kbd>C</kbd> / <kbd>Ctrl</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd> | Copy (or copy as plain text) |
| <kbd>Alt</kbd>+<kbd>1</kbd>…<kbd>9</kbd> | Quick paste the first nine visible clips |
| <kbd>Space</kbd> / <kbd>Ctrl</kbd>+<kbd>Space</kbd> | Toggle multi-select (space joins the filter if one is active) |
| <kbd>Ctrl</kbd>+<kbd>A</kbd> | Select all visible clips |
| <kbd>Enter</kbd> (with 2+ selected) | Merge selection & copy (Shift+Enter merges & pastes) |
| <kbd>Ctrl</kbd>+<kbd>P</kbd> | Toggle Pin / Unpin |
| <kbd>Ctrl</kbd>+<kbd>T</kbd> | Open the Transform picker (live preview, Enter copies, Shift+Enter copies & pastes) |
| <kbd>Ctrl</kbd>+<kbd>R</kbd> | Reveal/hide a sensitive clip |
| <kbd>Ctrl</kbd>+<kbd>I</kbd> | Toggle Incognito / pause capture |
| <kbd>Delete</kbd> | Delete selected clip (<kbd>Shift</kbd>+<kbd>Delete</kbd> clears unpinned history, with confirmation) |
| <kbd>Tab</kbd> / <kbd>Shift</kbd>+<kbd>Tab</kbd> | Cycle categories (All, Pinned, Colors, Code, Links, Images, Text) |
| <kbd>↑</kbd>/<kbd>↓</kbd>/<kbd>PgUp</kbd>/<kbd>PgDn</kbd>/<kbd>Home</kbd>/<kbd>End</kbd> | Move the cursor (`Ctrl`+<kbd>J</kbd>/<kbd>K</kbd> works too) |
| <kbd>Backspace</kbd> / <kbd>Ctrl</kbd>+<kbd>U</kbd> | Edit / clear the search filter |
| <kbd>Esc</kbd> | Clear selection → clear filter → dismiss (in that order) |

---

## Theming

ClipDeck renders with the same primitives as the built-in shell surfaces:

- `Border.surfaceSpec("menu", "border", …)` for the card border, so border width, radius, gradient, and opacity follow your theme's `[menu]` style block.
- `Color.menu.*` for background, text, scrim, and selection colors.
- `Color.accent` / `Color.urgent` for emphasis and destructive actions, with on-accent label colors derived by mixing against your palette (never hardcoded white/black).
- Syntax highlighting classes (`t-keyword`, `t-string`, `t-comment`, `t-json-key`, …) are mapped to theme-mixed tones at render time.

Switch themes and the deck follows instantly — no restart, no stale palette in stored previews.


---

## Screenshots

![ClipDeck overlay — Berserk (dark)](screenshots/dark.png)

![ClipDeck overlay — Catppuccin Latte (light)](screenshots/light.png)

The overlay is built entirely from Omarchy theme tokens, so it restyles live —
no restart — when you switch themes (`omarchy theme set ...`), exactly as in
the two captures above.

---

## Installation

### 1. Install or update the companion daemon (`clipdeckd`)

Use daemon **v0.5.1 or newer**. Download public distribution packages from
[GitHub releases](https://github.com/Mersad-Moghaddam/clipdeck/releases).
Use the versioned URLs below so the package name and release cannot drift apart.
Verify each downloaded package against the release's `SHA256SUMS` asset before
installing; stop if either the checksum download or verification fails.

**Recommended user-local installation (no root required):**

```bash
curl -fL https://raw.githubusercontent.com/Mersad-Moghaddam/clipdeck/v0.5.1/packaging/install.sh -o /tmp/clipdeck-install.sh &&
bash /tmp/clipdeck-install.sh --version 0.5.1 --daemon-only
```

The installer verifies release checksums, installs the daemon and CLI under
`~/.local/bin`, and enables the user service. Run it as your normal desktop
user, **not with sudo**. Existing history/configuration are preserved on upgrade.
On Omarchy, install `wl-clipboard` and `wtype` if `clipdeck doctor` reports them
missing. Review the downloaded script before executing it if preferred.

Alternatively, use the [v0.5.1 packages and SHA256SUMS](https://github.com/Mersad-Moghaddam/clipdeck/releases/tag/v0.5.1).
For Debian/Ubuntu amd64:

```bash
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.1/clipdeck_0.5.1_amd64.deb &&
curl -fLO https://github.com/Mersad-Moghaddam/clipdeck/releases/download/v0.5.1/SHA256SUMS &&
grep -E '  (\./)?clipdeck_0\.5\.1_amd64\.deb$' SHA256SUMS > package.sha256 &&
test -s package.sha256 && sha256sum -c package.sha256 &&
sudo apt install ./clipdeck_0.5.1_amd64.deb
```

RPM, APK and ARM64 daemon artifacts are also available; their availability is
not a claim that every distribution or architecture has been run-tested.

### Not using Omarchy? Install the standalone app instead

The shell plugin requires Omarchy 4; Ubuntu, Zorin and i3 users should use the
independent Qt popup from the companion repository, **not this shell plugin**:

```bash
bash /tmp/clipdeck-install.sh --version 0.5.1 --with-ui
```

Download the installer using the command above first. The optional GUI requires
Python **3.12+**, `python3-venv`, compatible Qt runtime libraries, and a graphical
desktop. It uses a private environment, not system-wide pip. Open **ClipDeck**
from the application menu or run `~/.local/bin/clipdeck-ui`.
X11 additionally needs `xclip`, `xdotool` and `xprop`; i3 floating/shortcut rules
are opt-in. See the [desktop setup and support matrix](https://github.com/Mersad-Moghaddam/clipdeck/blob/v0.5.1/docs/desktop-support.md)
for exact Debian/Ubuntu dependencies and limitations. Ubuntu 24.04 userspace and
nested i3/X11 were tested; full Zorin login and every Wayland compositor were not.
GNOME Wayland clipboard watching is unsupported; use an X11 session. Standalone
Wayland paste falls back explicitly to copy-only when safe targeting is unavailable.

**Manual setup required:** the native companion is installed separately; the plugin never downloads packages or requests root. Systemd-based native packages start the daemon automatically at the next graphical login. For this session, or an older installation, open ClipDeck and click **Start & enable at login**. No terminal service command is required. The action only enables/starts the already-installed user service; it cannot install a missing daemon. Non-systemd sessions need their own compositor autostart entry.

```bash
clipdeck doctor   # verify wl-clipboard, wtype, socket, database
```

### 2. Install Omarchy Plugin
Install the shell plugin via the Omarchy CLI:
```bash
omarchy plugin add https://github.com/Mersad-Moghaddam/omarchy-clipdeck.git --enable
```

Or install manually for development:
```bash
git clone https://github.com/Mersad-Moghaddam/omarchy-clipdeck.git ~/.config/omarchy/plugins/io.github.mersadmoghaddam.clipdeck
omarchy-shell shell rescanPlugins
omarchy plugin enable io.github.mersadmoghaddam.clipdeck --section right
```

### 3. Hyprland Keybinding
Add a binding in `~/.config/hypr/bindings.conf` or your Hyprland configuration:
```ini
bind = SUPER, V, exec, omarchy-shell shell toggle io.github.mersadmoghaddam.clipdeck '{}'
```

---

## Changelog
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
* Keyboard cursor re-anchors to the same clip across live reorders — Enter
  always pastes the row you are looking at, even when a capture lands
  mid-session.
* Unrevealed secrets can no longer leak through the transform picker
  (masked preview, transform requires Ctrl+R reveal).
* Merge-and-paste now hides the deck before dispatching the paste, like
  single paste.
* Pin/delete/merge failures surface as toasts; an optimistic pin rolls back
  when the daemon rejects it; deleted clips leave no ghost checkboxes;
  timed-out RPC calls fire their callbacks instead of hanging.
* Confirm dialogs preselect Cancel — muscle-memory Enter never wipes
  history.
* Search with no matches shows a clear-filter chip; empty history explains
  how capture and paste work.
* Hover quick-actions (Copy / Pin / ✕) and a batch Merge · Delete strip
  while multi-selecting; the inspector shows exact timestamps.
* Reliability: checkbox hit area fixed, external file:// passthrough,
  repaint on external pin changes, `json-number` syntax coloring, emoji
  never split mid-surrogate, bar socket falls back like the daemon when
  XDG_RUNTIME_DIR is unset.

### 0.2.0
* Initial marketplace release: list/search, keyboard-first paste, multi-
  select merge, pinned category, sensitive masking, transforms, color and
  image previews.

## License

MIT License. See [LICENSE](LICENSE) for details.
