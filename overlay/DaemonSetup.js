.pragma library

// Explicit user action only: installs no software and never requests root.
function enableAtLogin(exec) {
    exec(["systemctl", "--user", "enable", "--now", "clipdeckd.service"])
}
