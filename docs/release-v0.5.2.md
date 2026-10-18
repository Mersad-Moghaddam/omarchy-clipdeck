# ClipDeck Omarchy plugin v0.5.2

Updated installation guidance and release metadata for the public companion
v0.5.2. The Omarchy overlay, theme integration and keyboard behavior are unchanged.

## Install on Omarchy 4

Run as your normal desktop user, not root:

```bash
curl -fL https://raw.githubusercontent.com/Mersad-Moghaddam/clipdeck/v0.5.2/packaging/install.sh -o /tmp/clipdeck-install.sh &&
bash /tmp/clipdeck-install.sh --version 0.5.2 --daemon-only &&
omarchy plugin add https://github.com/Mersad-Moghaddam/omarchy-clipdeck.git --enable
```

See the README for dependencies, keyboard binding and diagnostics. Companion
installation remains manual; this plugin does not download or install the daemon.

## Companion v0.5.2

Available separately at https://github.com/Mersad-Moghaddam/clipdeck/releases/tag/v0.5.2:

- Private history-directory permissions and explicit systemd directory modes.
- Desktop-aware Qt palette/font and normal decorations outside Omarchy.
- Clear GNOME Wayland capture diagnostics and persistent standalone warning.
- DEB/RPM/APK and portable daemon/CLI artifacts; optional GUI via `--with-ui`.

The standalone GUI requires Python 3.12+ and compatible Qt runtime libraries.
Native GNOME Wayland automatic capture remains unsupported; use an Xorg/X11
session on Zorin. The reported remote daemon startup failure still needs its
service journal; this release does not claim it is fixed. Package availability
does not establish run-tested support on every distribution or architecture.

Public GitHub publication is separate from marketplace maintainer approval.
