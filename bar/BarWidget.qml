pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui

// ClipDeck bar widget: a live clip counter that summons the deck.
//
// Left click  — summon/hide the overlay (bar.run keeps the shell's panel
//               routing, so the widget works from any bar section).
// Middle/right — pause or resume capture (the label tints urgent while
//               paused, and the tooltip spells out the state).
//
// The count is fed by the daemon's own events (item_added, item_deleted,
// history_cleared, pause_changed) with a slow periodic status poll as a
// safety net, so the bar stays truthful without polling per keystroke.
BarWidget {
  id: root
  moduleName: "io.github.mersadmoghaddam.clipdeck"

  property int itemCount: 0
  property bool isPaused: false
  property bool connected: false
  property string runtimeDir: {
    var d = Quickshell.env("XDG_RUNTIME_DIR")
    return d !== "" ? d : "/tmp/run-clipdeck" // mirrors the daemon fallback
  }
  property string socketPath: root.runtimeDir + "/clipdeck/clipdeck.sock"

  readonly property bool opened: false

  function summon() { if (root.bar) root.bar.run("omarchy-shell shell summon " + root.moduleName + " '{}'") }
  function hide() { if (root.bar) root.bar.run("omarchy-shell shell hide " + root.moduleName) }
  function toggle() { if (root.bar) root.bar.run("omarchy-shell shell toggle " + root.moduleName + " '{}'") }

  readonly property string countLabel: root.itemCount > 999 ? "999+" : String(root.itemCount)

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // The socket lives behind a Loader so retries can recreate it: a Socket
  // whose first connection attempt fails never connects again in Quickshell
  // 0.3.1, and the bar must recover when the daemon restarts.
  readonly property var ipcSocket: ipcLoader.item

  Loader {
    id: ipcLoader
    sourceComponent: ipcComp
  }

  Timer {
    id: ipcKick
    interval: 16
    repeat: false
    onTriggered: ipcLoader.active = true
  }

  Component {
    id: ipcComp
    Socket {
      id: barSock
      path: root.socketPath
      connected: true

      onConnectionStateChanged: {
        root.connected = barSock.connected
        if (barSock.connected) root.requestStatus()
      }

      parser: SplitParser {
        splitMarker: "\n"
        onRead: function (data) { root.handleIpcMessage(data) }
      }
    }
  }

  Timer {
    id: reconnectTimer
    interval: 3000
    repeat: true
    running: !root.connected
    onTriggered: {
      if (root.connected) return
      ipcLoader.active = false   // fresh socket: errored ones never retry
      ipcKick.restart()
    }
  }

  // Safety net for missed events (retention purges, TTL expiry) — cheap
  // enough at this cadence and keeps the count honest.
  Timer {
    id: statusTimer
    interval: 15000
    repeat: true
    running: root.connected
    onTriggered: root.requestStatus()
  }

  function requestStatus() {
    if (!ipcSocket || !ipcSocket.connected) return
    ipcSocket.write(JSON.stringify({ id: "status-poll", method: "status", params: null }) + "\n")
    ipcSocket.flush()
  }

  function togglePause() {
    if (!ipcSocket || !ipcSocket.connected) return
    ipcSocket.write(JSON.stringify({ id: "pause-toggle", method: "pause", params: { paused: !root.isPaused } }) + "\n")
    ipcSocket.flush()
  }

  function handleIpcMessage(raw) {
    var trimmed = String(raw || "").trim()
    if (!trimmed) return
    try {
      var msg = JSON.parse(trimmed)
      if (msg.event === "item_added" || msg.event === "item_deleted" || msg.event === "history_cleared") {
        root.requestStatus()
      } else if (msg.event === "pause_changed" && msg.data) {
        root.isPaused = msg.data.paused === true
      } else if (msg.id === "status-poll" && msg.result) {
        root.itemCount = msg.result.total_items || 0
        root.isPaused = msg.result.paused === true
      } else if (msg.id === "pause-toggle" && msg.result) {
        root.isPaused = msg.result.paused === true
      }
    } catch (e) {}
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar

    // The clipboard glyph is a Nerd Font codepoint, matching the bar's own
    // icon language (the bar font is the patched family by default).
    text: "󰅌 " + root.countLabel
    fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

    active: root.isPaused
    activeColor: Color.urgent

    tooltipText: {
      var state = root.connected
        ? (root.isPaused ? "capture PAUSED — clips are not being recorded" : "recording — " + root.itemCount + " clips stored")
        : "daemon offline — run clipdeck doctor to diagnose"
      return "ClipDeck\n" + state + "\nLeft click: open the deck · middle/right: pause capture"
    }

    onPressed: function (mouseButton) {
      if (mouseButton === Qt.MiddleButton || mouseButton === Qt.RightButton) root.togglePause()
      else root.toggle()
    }
  }
}
