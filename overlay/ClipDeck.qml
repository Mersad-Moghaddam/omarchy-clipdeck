pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui

Item {
  id: root

  // Injected properties from Omarchy shell
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // Overlay state
  property bool opened: false
  property string profile: ""
  property string searchQuery: ""
  property string activeCategory: "all" // all, pinned, code, color, image, link, text
  property int selectedIndex: 0
  property var items: []
  property var filteredItems: []
  property bool isConnected: false
  property bool isPaused: false
  property var activeItem: filteredItems.length > selectedIndex && selectedIndex >= 0 ? filteredItems[selectedIndex] : null

  // Transform picker dialog state
  property bool transformPickerOpen: false
  property int transformPickerIndex: 0
  readonly property var availableTransforms: [
    { id: "uppercase", name: "UPPERCASE", desc: "Convert text to all uppercase" },
    { id: "lowercase", name: "lowercase", desc: "Convert text to all lowercase" },
    { id: "title", name: "Title Case", desc: "Capitalize first letter of each word" },
    { id: "camel", name: "camelCase", desc: "Convert text to camelCase" },
    { id: "snake", name: "snake_case", desc: "Convert text to snake_case" },
    { id: "kebab", name: "kebab-case", desc: "Convert text to kebab-case" },
    { id: "trim", name: "Trim Whitespace", desc: "Remove leading and trailing whitespace" },
    { id: "json_pretty", name: "Format JSON", desc: "Prettify JSON with indentation" },
    { id: "base64_encode", name: "Base64 Encode", desc: "Encode text into base64" },
    { id: "base64_decode", name: "Base64 Decode", desc: "Decode base64 string" },
    { id: "url_encode", name: "URL Encode", desc: "Percent-encode URL parameters" },
    { id: "url_decode", name: "URL Decode", desc: "Decode percent-encoded URL" },
    { id: "sort_lines", name: "Sort Lines", desc: "Sort text lines alphabetically" },
    { id: "dedupe_lines", name: "Deduplicate Lines", desc: "Remove duplicate lines" },
    { id: "persian_digits_to_latin", name: "Persian Digits → Latin (۰۱۲ → 012)", desc: "Convert Eastern Arabic-Indic numerals to Latin" },
    { id: "latin_digits_to_persian", name: "Latin Digits → Persian (012 → ۰۱۲)", desc: "Convert Latin numerals to Persian" },
    { id: "arabic_digits_to_persian", name: "Arabic Digits → Persian (٠١٢ → ۰۱۲)", desc: "Convert Arabic-Indic numerals to Persian" },
    { id: "arabic_to_persian_letters", name: "Arabic Letters → Persian (ي/ك → ی/ک)", desc: "Normalize Arabic letters to Persian" },
    { id: "normalize_zwnj", name: "Normalize ZWNJ (نیم‌فاصله)", desc: "Fix ZWNJ around prefixes and suffixes" },
    { id: "persian_all", name: "Standardize Persian (All)", desc: "Run all Persian text & digit normalizations" }
  ]

  // Theme tokens dynamically tied to active Omarchy theme
  readonly property color bg: Color.menu.background
  readonly property color fg: Color.menu.text
  readonly property color borderCol: Color.menu.border
  readonly property color scrimCol: Color.menu.scrim
  readonly property color selBg: Color.menu.selectedBackground
  readonly property color selFg: Color.menu.selectedText
  readonly property color accentCol: Color.accent
  readonly property color mutedCol: Color.muted
  readonly property color urgentCol: Color.urgent
  readonly property int radius: Style.cornerRadius
  readonly property string fontFam: Style.font.menuFamily
  readonly property string codeFam: Style.font.family

  // Socket path
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string socketPath: {
    var sub = root.profile === "dev" ? "clipdeck-dev" : "clipdeck"
    return root.runtimeDir + "/" + sub + "/clipdeck.sock"
  }

  // Pending RPC callbacks
  property var pendingCallbacks: ({})
  property int nextReqId: 1

  function open(payloadJson) {
    if (payloadJson) {
      try {
        var p = JSON.parse(payloadJson)
        if (p.profile) root.profile = p.profile
      } catch (e) {}
    }
    root.opened = true
    root.searchQuery = ""
    root.activeCategory = "all"
    root.selectedIndex = 0
    root.transformPickerOpen = false
    root.connectSocket()
    root.refreshList()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
    root.transformPickerOpen = false
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function connectSocket() {
    if (!ipcSocket.connected) {
      ipcSocket.path = root.socketPath
      ipcSocket.connected = true
    }
  }

  function sendRpc(method, params, callback) {
    if (!ipcSocket.connected) return
    var id = "req-" + (root.nextReqId++)
    if (callback) {
      root.pendingCallbacks[id] = callback
    }
    var msg = JSON.stringify({ id: id, method: method, params: params })
    ipcSocket.write(msg + "\n")
    ipcSocket.flush()
  }

  function refreshList() {
    if (root.searchQuery.trim() !== "") {
      root.sendRpc("search", { query: root.searchQuery.trim(), limit: 100 }, function(res) {
        if (res && res.items) {
          root.items = res.items
          root.applyFilter()
        }
      })
    } else {
      root.sendRpc("list", { limit: 100 }, function(res) {
        if (res && res.items) {
          root.items = res.items
          root.applyFilter()
        }
      })
    }
    root.sendRpc("status", null, function(res) {
      if (res) {
        root.isPaused = res.paused === true
      }
    })
  }

  function applyFilter() {
    var out = []
    for (var i = 0; i < root.items.length; i++) {
      var it = root.items[i]
      if (root.activeCategory === "all") {
        out.push(it)
      } else if (root.activeCategory === "pinned" && it.pinned) {
        out.push(it)
      } else if (root.activeCategory === it.type) {
        out.push(it)
      }
    }
    root.filteredItems = out
    if (root.selectedIndex >= out.length) {
      root.selectedIndex = Math.max(0, out.length - 1)
    }
  }

  function handleMessage(raw) {
    var trimmed = raw.trim()
    if (!trimmed) return
    try {
      var msg = JSON.parse(trimmed)
      if (msg.event) {
        // Asynchronous event from daemon
        root.handleBroadcast(msg.event, msg.data)
      } else if (msg.id && root.pendingCallbacks[msg.id]) {
        var cb = root.pendingCallbacks[msg.id]
        delete root.pendingCallbacks[msg.id]
        cb(msg.result)
      }
    } catch (e) {
      console.log("Error parsing IPC message:", e, trimmed)
    }
  }

  function handleBroadcast(event, data) {
    if (event === "item_added" || event === "item_updated" || event === "item_deleted" || event === "history_cleared" || event === "pin_changed") {
      root.refreshList()
    } else if (event === "pause_changed") {
      if (data && typeof data.paused === "boolean") {
        root.isPaused = data.paused
      }
    }
  }

  function actionPaste(item, plain) {
    if (!item) return
    root.close()
    root.sendRpc("paste", { id: item.id, plain: plain, transform: "" }, null)
  }

  function actionCopy(item, plain) {
    if (!item) return
    root.sendRpc("copy", { id: item.id, plain: plain, transform: "" }, function() {
      root.close()
    })
  }

  function actionTogglePin(item) {
    if (!item) return
    root.sendRpc("pin", { id: item.id, pinned: !item.pinned }, function() {
      root.refreshList()
    })
  }

  function actionDelete(item) {
    if (!item) return
    root.sendRpc("delete", { id: item.id }, function() {
      root.refreshList()
    })
  }

  function actionClear() {
    root.sendRpc("clear", { include_pinned: false }, function() {
      root.refreshList()
    })
  }

  function actionTogglePause() {
    root.sendRpc("pause", { paused: !root.isPaused }, function(res) {
      if (res) root.isPaused = res.paused === true
    })
  }

  function actionApplyTransform(transformId) {
    if (!root.activeItem) return
    root.sendRpc("transform", { id: root.activeItem.id, action: transformId }, function(res) {
      root.transformPickerOpen = false
      if (res && res.text) {
        // Copy transformed text
        root.sendRpc("copy", { id: root.activeItem.id, plain: true, transform: transformId }, function() {
          root.close()
        })
      }
    })
  }

  function isRTL(text) {
    if (!text) return false
    var arabicPersianPattern = /[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]/
    return arabicPersianPattern.test(text.substring(0, 200))
  }

  function formatBytes(bytes) {
    if (bytes <= 0) return "0 B"
    if (bytes < 1024) return bytes + " B"
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
    return (bytes / (1024 * 1024)).toFixed(1) + " MB"
  }

  function formatTimeAgo(epochMs) {
    if (!epochMs) return ""
    var sec = Math.floor((Date.now() - epochMs) / 1000)
    if (sec < 60) return "just now"
    if (sec < 3600) return Math.floor(sec / 60) + "m ago"
    if (sec < 86400) return Math.floor(sec / 3600) + "h ago"
    return Math.floor(sec / 86400) + "d ago"
  }

  function handleKeyEvent(event) {
    // Transform picker navigation
    if (root.transformPickerOpen) {
      if (event.key === Qt.Key_Escape) {
        root.transformPickerOpen = false
        event.accepted = true
      } else if (event.key === Qt.Key_Up) {
        root.transformPickerIndex = (root.transformPickerIndex - 1 + root.availableTransforms.length) % root.availableTransforms.length
        transformList.positionViewAtIndex(root.transformPickerIndex, ListView.Contain)
        event.accepted = true
      } else if (event.key === Qt.Key_Down) {
        root.transformPickerIndex = (root.transformPickerIndex + 1) % root.availableTransforms.length
        transformList.positionViewAtIndex(root.transformPickerIndex, ListView.Contain)
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        var selTr = root.availableTransforms[root.transformPickerIndex]
        if (selTr) root.actionApplyTransform(selTr.id)
        event.accepted = true
      }
      return
    }

    // Main overlay key handling
    if (event.key === Qt.Key_Escape) {
      if (root.searchQuery !== "") {
        root.searchQuery = ""
        root.refreshList()
      } else {
        root.close()
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Up) {
      if (root.filteredItems.length > 0) {
        root.selectedIndex = (root.selectedIndex - 1 + root.filteredItems.length) % root.filteredItems.length
        itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Down) {
      if (root.filteredItems.length > 0) {
        root.selectedIndex = (root.selectedIndex + 1) % root.filteredItems.length
        itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      }
      event.accepted = true
    } else if (event.key === Qt.Key_PageUp) {
      if (root.filteredItems.length > 0) {
        root.selectedIndex = Math.max(0, root.selectedIndex - 6)
        itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      }
      event.accepted = true
    } else if (event.key === Qt.Key_PageDown) {
      if (root.filteredItems.length > 0) {
        root.selectedIndex = Math.min(root.filteredItems.length - 1, root.selectedIndex + 6)
        itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      var plain = (event.modifiers & Qt.ShiftModifier) !== 0
      root.actionPaste(root.activeItem, plain)
      event.accepted = true
    } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
      var plainCopy = (event.modifiers & Qt.ShiftModifier) !== 0
      root.actionCopy(root.activeItem, plainCopy)
      event.accepted = true
    } else if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
      root.actionTogglePin(root.activeItem)
      event.accepted = true
    } else if (event.key === Qt.Key_I && (event.modifiers & Qt.ControlModifier)) {
      root.actionTogglePause()
      event.accepted = true
    } else if (event.key === Qt.Key_T && (event.modifiers & Qt.ControlModifier)) {
      if (root.activeItem && root.activeItem.type !== "image") {
        root.transformPickerIndex = 0
        root.transformPickerOpen = true
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Delete) {
      if (event.modifiers & Qt.ShiftModifier) {
        root.actionClear()
      } else {
        root.actionDelete(root.activeItem)
      }
      event.accepted = true
    } else if (event.key === Qt.Key_Tab) {
      // Cycle category tabs
      var cats = ["all", "pinned", "code", "color", "image", "link", "text"]
      var curIdx = cats.indexOf(root.activeCategory)
      var nextIdx = (curIdx + 1) % cats.length
      root.activeCategory = cats[nextIdx]
      root.applyFilter()
      event.accepted = true
    } else if (event.text && event.text.length > 0 && !event.modifiers) {
      // Typing characters routes to search box
      searchInput.forceActiveFocus()
      searchInput.text = searchInput.text + event.text
      root.searchQuery = searchInput.text
      root.refreshList()
      event.accepted = true
    }
  }

  // Socket Connection to clipdeckd
  Socket {
    id: ipcSocket
    path: root.socketPath
    connected: false
    onConnectionStateChanged: {
      root.isConnected = ipcSocket.connected
      if (ipcSocket.connected) {
        root.refreshList()
      }
    }
    onError: function(err) {
      root.isConnected = false
    }
    parser: SplitParser {
      splitMarker: "\n"
      onRead: function(data) {
        root.handleMessage(data)
      }
    }
  }

  // Wayland Layer Shell Overlay Window
  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "clipdeck-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Scrim backdrop
    Rectangle {
      anchors.fill: parent
      color: root.scrimCol
      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }
    }

    // Modal Card
    Rectangle {
      id: card
      width: Math.min(Style.space(960), panel.width - Style.gapsOut * 2)
      height: Math.min(Style.space(660), panel.height - Style.gapsOut * 2)
      radius: root.radius
      anchors.centerIn: parent
      color: root.bg
      border.color: root.borderCol
      border.width: Math.max(1, Style.space(1.5))
      clip: true

      MouseArea {
        anchors.fill: parent
        onClicked: {} // Catch clicks so backdrop doesn't dismiss
      }

      // Main Keyboard Handler
      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          root.handleKeyEvent(event)
        }

        // Header / Search Bar
        Rectangle {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(64)
          color: root.bg
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(16)
            anchors.rightMargin: Style.space(16)
            spacing: Style.space(12)

            // Logo & Title
            Text {
              Layout.alignment: Qt.AlignVCenter
              text: "ClipDeck"
              font.family: root.fontFam
              font.pixelSize: Style.font.title
              font.bold: true
              color: root.accentCol
            }

            // Incognito / Active badge
            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              Layout.preferredHeight: Style.space(22)
              Layout.preferredWidth: incognitoText.implicitWidth + Style.space(14)
              radius: root.radius / 2
              color: root.isPaused ? root.urgentCol : Qt.rgba(root.accentCol.r, root.accentCol.g, root.accentCol.b, 0.15)
              border.color: root.isPaused ? root.urgentCol : root.accentCol
              border.width: 1

              Text {
                id: incognitoText
                anchors.centerIn: parent
                text: root.isPaused ? "PAUSED" : "ACTIVE"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                font.bold: true
                color: root.isPaused ? "#ffffff" : root.accentCol
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.actionTogglePause()
              }
            }

            // Search Text Field
            Rectangle {
              Layout.fillWidth: true
              Layout.preferredHeight: Style.space(38)
              Layout.alignment: Qt.AlignVCenter
              radius: root.radius / 2
              color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)
              border.color: searchInput.activeFocus ? root.accentCol : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.15)
              border.width: 1

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(10)
                anchors.rightMargin: Style.space(10)
                spacing: Style.space(6)

                Text {
                  Layout.alignment: Qt.AlignVCenter
                  text: "🔍"
                  font.pixelSize: Style.font.body
                  color: root.mutedCol
                }

                TextInput {
                  id: searchInput
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  text: root.searchQuery
                  font.family: root.fontFam
                  font.pixelSize: Style.font.body
                  color: root.fg
                  selectByMouse: true
                  clip: true

                  onTextChanged: {
                    root.searchQuery = searchInput.text
                    root.refreshList()
                  }

                  Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_Up || event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Escape) {
                      keyCatcher.forceActiveFocus()
                      root.handleKeyEvent(event)
                    }
                  }

                  Text {
                    anchors.fill: parent
                    visible: !searchInput.text && !searchInput.activeFocus
                    text: "Search clipboard history... (type anywhere)"
                    font.family: root.fontFam
                    font.pixelSize: Style.font.body
                    color: root.mutedCol
                  }
                }

                // Clear search icon
                Text {
                  visible: searchInput.text !== ""
                  Layout.alignment: Qt.AlignVCenter
                  text: "✕"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.body
                  color: root.mutedCol
                  MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      searchInput.text = ""
                      root.searchQuery = ""
                      root.refreshList()
                    }
                  }
                }
              }
            }

            // Item count label
            Text {
              Layout.alignment: Qt.AlignVCenter
              text: root.filteredItems.length + " items"
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: root.mutedCol
            }
          }
        }

        // Category Filter Chips
        Rectangle {
          id: categoryBar
          anchors.top: header.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(38)
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.02)
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(16)
            spacing: Style.space(8)

            Repeater {
              model: [
                { id: "all", label: "All" },
                { id: "pinned", label: "★ Pinned" },
                { id: "code", label: "Code" },
                { id: "color", label: "Colors" },
                { id: "image", label: "Images" },
                { id: "link", label: "Links" },
                { id: "text", label: "Text" }
              ]

              Rectangle {
                required property var modelData
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredHeight: Style.space(26)
                Layout.preferredWidth: chipText.implicitWidth + Style.space(16)
                radius: root.radius / 2
                color: root.activeCategory === modelData.id ? root.accentCol : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.06)

                Text {
                  id: chipText
                  anchors.centerIn: parent
                  text: parent.modelData.label
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: root.activeCategory === parent.modelData.id
                  color: root.activeCategory === parent.modelData.id ? "#ffffff" : root.fg
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    root.activeCategory = parent.modelData.id
                    root.applyFilter()
                  }
                }
              }
            }
          }
        }

        // Split Pane Body
        Item {
          id: splitBody
          anchors.top: categoryBar.bottom
          anchors.bottom: footer.top
          anchors.left: parent.left
          anchors.right: parent.right

          // Offline Daemon State
          Rectangle {
            anchors.fill: parent
            visible: !root.isConnected
            color: root.bg
            z: 10

            ColumnLayout {
              anchors.centerIn: parent
              spacing: Style.space(14)

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "⚠️ Daemon Offline"
                font.family: root.fontFam
                font.pixelSize: Style.font.title
                font.bold: true
                color: root.urgentCol
              }

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: "ClipDeck background daemon is not running.\nStart it with:\n\nsystemctl --user start clipdeckd\n\nor run 'clipdeckd' in your terminal."
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                color: root.fg
                horizontalAlignment: Text.AlignHCenter
              }

              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredHeight: Style.space(34)
                Layout.preferredWidth: Style.space(120)
                radius: root.radius / 2
                color: root.accentCol

                Text {
                  anchors.centerIn: parent
                  text: "Retry Connection"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: "#ffffff"
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.connectSocket()
                }
              }
            }
          }

          // Left Pane: Virtualized List View (45% width)
          Rectangle {
            id: leftPane
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: parent.width * 0.44
            color: root.bg
            border.color: root.borderCol
            border.width: 1

            ListView {
              id: itemsList
              anchors.fill: parent
              anchors.margins: Style.space(4)
              model: root.filteredItems
              clip: true
              spacing: Style.space(4)

              delegate: Rectangle {
                id: rowDelegate
                required property var modelData
                required property int index

                width: itemsList.width
                height: Style.space(64)
                radius: root.radius / 2
                color: root.selectedIndex === index ? root.selBg : (rowMouse.containsMouse ? Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.05) : "transparent")
                border.color: root.selectedIndex === index ? root.accentCol : "transparent"
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  spacing: Style.space(10)

                  // Type icon / Color swatch badge
                  Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Style.space(36)
                    Layout.preferredHeight: Style.space(36)
                    radius: root.radius / 2
                    color: rowDelegate.modelData.type === "color" ? rowDelegate.modelData.preview : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    border.color: root.borderCol
                    border.width: 1

                    Text {
                      visible: rowDelegate.modelData.type !== "color" && rowDelegate.modelData.type !== "image"
                      anchors.centerIn: parent
                      text: {
                        var t = rowDelegate.modelData.type
                        if (t === "code") return "💻"
                        if (t === "link") return "🔗"
                        if (t === "json") return "{ }"
                        if (t === "email") return "✉"
                        if (t === "phone") return "📞"
                        if (t === "path") return "📁"
                        if (t === "number") return "#"
                        return "📄"
                      }
                      font.pixelSize: Style.font.body
                    }

                    Image {
                      visible: rowDelegate.modelData.type === "image" && (rowDelegate.modelData.thumbnail_path || rowDelegate.modelData.blob_path) !== ""
                      anchors.fill: parent
                      anchors.margins: 2
                      source: Util.fileUrl(rowDelegate.modelData.thumbnail_path || rowDelegate.modelData.blob_path)
                      fillMode: Image.PreserveAspectFit
                    }
                  }

                  // Title / Preview Text
                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        visible: rowDelegate.modelData.pinned
                        text: "★"
                        font.pixelSize: Style.font.caption
                        color: root.accentCol
                      }

                      Text {
                        text: rowDelegate.modelData.source_app || "clipboard"
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        color: root.selectedIndex === rowDelegate.index ? root.selFg : root.mutedCol
                      }

                      Item { Layout.fillWidth: true }

                      Text {
                        text: root.formatTimeAgo(Date.parse(rowDelegate.modelData.created_at))
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        color: root.selectedIndex === rowDelegate.index ? root.selFg : root.mutedCol
                      }
                    }

                    // Strict Text.PlainText snippet (Security rule)
                    Text {
                      Layout.fillWidth: true
                      text: rowDelegate.modelData.preview || rowDelegate.modelData.content
                      font.family: root.fontFam
                      font.pixelSize: Style.font.body
                      font.bold: root.selectedIndex === rowDelegate.index
                      color: root.selectedIndex === rowDelegate.index ? root.selFg : root.fg
                      textFormat: Text.PlainText
                      elide: Text.ElideRight
                      maximumLineCount: 1
                    }
                  }
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: {
                    root.selectedIndex = rowDelegate.index
                  }
                  onDoubleClicked: {
                    root.actionPaste(rowDelegate.modelData, false)
                  }
                }
              }

              // Empty state
              Text {
                visible: root.filteredItems.length === 0 && root.isConnected
                anchors.centerIn: parent
                text: "No clipboard items found."
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                color: root.mutedCol
              }
            }
          }

          // Right Pane: Inspector & Full Preview (56% width)
          Rectangle {
            id: rightPane
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: leftPane.right
            anchors.right: parent.right
            color: root.bg

            Item {
              anchors.fill: parent
              anchors.margins: Style.space(16)
              visible: root.activeItem !== null

              ColumnLayout {
                anchors.fill: parent
                spacing: Style.space(12)

                // Inspector Metadata Header
                Rectangle {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(48)
                  radius: root.radius / 2
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.04)
                  border.color: root.borderCol
                  border.width: 1

                  RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(12)
                    anchors.rightMargin: Style.space(12)
                    spacing: Style.space(12)

                    // Type chip
                    Rectangle {
                      Layout.alignment: Qt.AlignVCenter
                      Layout.preferredHeight: Style.space(22)
                      Layout.preferredWidth: typeLabel.implicitWidth + Style.space(12)
                      radius: root.radius / 2
                      color: root.accentCol

                      Text {
                        id: typeLabel
                        anchors.centerIn: parent
                        text: (root.activeItem ? root.activeItem.type : "").toUpperCase()
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: "#ffffff"
                      }
                    }

                    // Source application
                    Text {
                      Layout.alignment: Qt.AlignVCenter
                      text: "App: " + (root.activeItem ? root.activeItem.source_app : "")
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      color: root.mutedCol
                    }

                    // Size
                    Text {
                      Layout.alignment: Qt.AlignVCenter
                      text: "Size: " + (root.activeItem ? root.formatBytes(root.activeItem.size_bytes) : "")
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      color: root.mutedCol
                    }

                    Item { Layout.fillWidth: true }

                    // Pin toggle button
                    Rectangle {
                      Layout.alignment: Qt.AlignVCenter
                      Layout.preferredHeight: Style.space(26)
                      Layout.preferredWidth: Style.space(26)
                      radius: root.radius / 2
                      color: root.activeItem && root.activeItem.pinned ? root.accentCol : Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)

                      Text {
                        anchors.centerIn: parent
                        text: "★"
                        font.pixelSize: Style.font.body
                        color: root.activeItem && root.activeItem.pinned ? "#ffffff" : root.fg
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.actionTogglePin(root.activeItem)
                      }
                    }
                  }
                }

                // Inspector Content Area
                Rectangle {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  radius: root.radius / 2
                  color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.02)
                  border.color: root.borderCol
                  border.width: 1
                  clip: true

                  // 1. Color Preview
                  ColumnLayout {
                    anchors.centerIn: parent
                    visible: root.activeItem && root.activeItem.type === "color"
                    spacing: Style.space(14)

                    Rectangle {
                      Layout.alignment: Qt.AlignHCenter
                      Layout.preferredWidth: Style.space(180)
                      Layout.preferredHeight: Style.space(120)
                      radius: root.radius
                      color: root.activeItem ? root.activeItem.preview : "transparent"
                      border.color: root.borderCol
                      border.width: 2
                    }

                    Text {
                      Layout.alignment: Qt.AlignHCenter
                      text: root.activeItem ? root.activeItem.content : ""
                      font.family: root.codeFam
                      font.pixelSize: Style.font.title
                      font.bold: true
                      color: root.fg
                    }
                  }

                  // 2. Image Preview
                  Item {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    visible: root.activeItem && root.activeItem.type === "image"

                    Image {
                      anchors.fill: parent
                      source: root.activeItem && (root.activeItem.blob_path || root.activeItem.thumbnail_path) ? Util.fileUrl(root.activeItem.blob_path || root.activeItem.thumbnail_path) : ""
                      fillMode: Image.PreserveAspectFit
                    }
                  }

                  // 3. Syntax-highlighted Code View (daemon-escaped rich text)
                  Flickable {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    visible: root.activeItem && (root.activeItem.type === "code" || root.activeItem.type === "json") && root.activeItem.rich_preview !== ""
                    contentWidth: codeRichText.paintedWidth
                    contentHeight: codeRichText.paintedHeight
                    clip: true

                    Text {
                      id: codeRichText
                      text: root.activeItem ? root.activeItem.rich_preview : ""
                      font.family: root.codeFam
                      font.pixelSize: Style.font.body
                      textFormat: Text.RichText
                    }
                  }

                  // 4. Standard Text Viewer (STRICT Text.PlainText - PRD §9 security constraint)
                  Flickable {
                    anchors.fill: parent
                    anchors.margins: Style.space(12)
                    visible: root.activeItem && root.activeItem.type !== "image" && root.activeItem.type !== "color" && (!root.activeItem.rich_preview || (root.activeItem.type !== "code" && root.activeItem.type !== "json"))
                    contentWidth: plainTextView.paintedWidth
                    contentHeight: plainTextView.paintedHeight
                    clip: true

                    Text {
                      id: plainTextView
                      width: parent.width
                      text: root.activeItem ? root.activeItem.content : ""
                      font.family: root.isRTL(text) ? Style.font.family : root.fontFam
                      font.pixelSize: Style.font.body
                      color: root.fg
                      textFormat: Text.PlainText
                      wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                      horizontalAlignment: root.isRTL(text) ? Text.AlignRight : Text.AlignLeft
                    }
                  }
                }

                // Quick Action Bar
                RowLayout {
                  Layout.fillWidth: true
                  Layout.preferredHeight: Style.space(34)
                  spacing: Style.space(8)

                  // Paste Button
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.radius / 2
                    color: root.accentCol

                    Text {
                      anchors.centerIn: parent
                      text: "⏎ Paste to Window"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: "#ffffff"
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.actionPaste(root.activeItem, false)
                    }
                  }

                  // Copy Button
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: root.radius / 2
                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    border.color: root.borderCol
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "📋 Copy"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.fg
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.actionCopy(root.activeItem, false)
                    }
                  }

                  // Transforms Button
                  Rectangle {
                    visible: root.activeItem && root.activeItem.type !== "image"
                    Layout.preferredWidth: Style.space(110)
                    Layout.fillHeight: true
                    radius: root.radius / 2
                    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.08)
                    border.color: root.borderCol
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "⚡ Transform"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.fg
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.transformPickerIndex = 0
                        root.transformPickerOpen = true
                      }
                    }
                  }
                }
              }
            }

            // No active item placeholder
            Text {
              visible: root.activeItem === null && root.isConnected
              anchors.centerIn: parent
              text: "Select an item to inspect"
              font.family: root.fontFam
              font.pixelSize: Style.font.body
              color: root.mutedCol
            }
          }
        }

        // Footer / Keybindings Guide
        Rectangle {
          id: footer
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(38)
          color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.03)
          border.color: root.borderCol
          border.width: 1

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(16)
            anchors.rightMargin: Style.space(16)
            spacing: Style.space(14)

            Text {
              Layout.alignment: Qt.AlignVCenter
              text: "⏎ Paste  •  ⇧⏎ Plain Paste  •  Ctrl+C Copy  •  Ctrl+P Pin  •  Ctrl+T Transform  •  Del Delete  •  Esc Close"
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: root.mutedCol
            }

            Item { Layout.fillWidth: true }

            Text {
              Layout.alignment: Qt.AlignVCenter
              text: "Omarchy Quattro"
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: root.mutedCol
            }
          }
        }

        // Transform Picker Modal Dialog
        Rectangle {
          id: transformDialog
          visible: root.transformPickerOpen
          anchors.fill: parent
          color: Qt.rgba(0, 0, 0, 0.6)
          z: 50

          Rectangle {
            width: Style.space(480)
            height: Style.space(420)
            anchors.centerIn: parent
            radius: root.radius
            color: root.bg
            border.color: root.accentCol
            border.width: 2
            clip: true

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(16)
              spacing: Style.space(10)

              RowLayout {
                Layout.fillWidth: true
                Text {
                  text: "⚡ Apply Text Transform"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.title
                  font.bold: true
                  color: root.accentCol
                }
                Item { Layout.fillWidth: true }
                Text {
                  text: "Esc to close"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  color: root.mutedCol
                }
              }

              ListView {
                id: transformList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.availableTransforms
                clip: true
                spacing: Style.space(4)

                delegate: Rectangle {
                  id: trDelegate
                  required property var modelData
                  required property int index

                  width: transformList.width
                  height: Style.space(44)
                  radius: root.radius / 2
                  color: root.transformPickerIndex === index ? root.selBg : "transparent"
                  border.color: root.transformPickerIndex === index ? root.accentCol : "transparent"
                  border.width: 1

                  ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    spacing: Style.space(2)

                    Text {
                      text: trDelegate.modelData.name
                      font.family: root.fontFam
                      font.pixelSize: Style.font.body
                      font.bold: root.transformPickerIndex === trDelegate.index
                      color: root.transformPickerIndex === trDelegate.index ? root.selFg : root.fg
                    }
                    Text {
                      text: trDelegate.modelData.desc
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      color: root.transformPickerIndex === trDelegate.index ? root.selFg : root.mutedCol
                    }
                  }

                  MouseArea {
                    anchors.fill: parent
                    onClicked: {
                      root.transformPickerIndex = trDelegate.index
                      root.actionApplyTransform(trDelegate.modelData.id)
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
