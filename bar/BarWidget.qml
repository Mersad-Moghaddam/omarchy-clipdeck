import Quickshell
import Quickshell.Io
import QtQuick
import qs.Commons
import qs.Ui as Ui

Ui.BarWidget {
  id: root
  moduleName: "clipdeck"

  property int itemCount: 0
  property bool isPaused: false
  property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  property string socketPath: root.runtimeDir + "/clipdeck/clipdeck.sock"

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Socket {
    id: ipcSocket
    path: root.socketPath
    connected: false

    onConnectionStateChanged: {
      if (ipcSocket.connected) {
        root.requestStatus()
      }
    }

    parser: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        root.handleIpcMessage(data)
      }
    }
  }

  Timer {
    id: reconnectTimer
    interval: 3000
    repeat: true
    running: !ipcSocket.connected
    onTriggered: {
      if (!ipcSocket.connected) {
        ipcSocket.connected = true
      }
    }
  }

  function requestStatus() {
    if (!ipcSocket.connected) return
    var msg = JSON.stringify({ id: "status-poll", method: "status", params: null })
    ipcSocket.write(msg + "\n")
    ipcSocket.flush()
  }

  function togglePause() {
    if (!ipcSocket.connected) return
    var msg = JSON.stringify({ id: "pause-toggle", method: "pause", params: { paused: !root.isPaused } })
    ipcSocket.write(msg + "\n")
    ipcSocket.flush()
  }

  function handleIpcMessage(raw) {
    var trimmed = raw.trim()
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

  Component.onCompleted: {
    ipcSocket.connected = true
  }

  Ui.WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "📋 " + (root.isPaused ? "⏸" : String(root.itemCount))
    tooltipText: "ClipDeck (" + root.itemCount + " items)" + (root.isPaused ? " [PAUSED]" : "") + "\nLeft-click: toggle overlay\nMiddle-click: toggle pause"
    active: root.isPaused
    activeColor: Color.urgent

    onPressed: function(mouseButton) {
      if (!root.bar) return
      if (mouseButton === Qt.MiddleButton || mouseButton === Qt.RightButton) {
        root.togglePause()
      } else {
        root.bar.run("omarchy-shell shell toggle io.github.mersadmoghaddam.clipdeck '{}'")
      }
    }
  }
}
