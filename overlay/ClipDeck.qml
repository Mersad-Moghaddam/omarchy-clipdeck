pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Ui
import "./DeckTheme.js" as DeckTheme
import "../components"

// ClipDeck overlay — a keyboard-first, theme-native view over the clipdeckd
// daemon.
//
// Design contract:
//   * Every color, radius, space, and font size comes from the live Omarchy
//     theme (Color.menu.*, Color.accent, Style.*). Derived tones are mixed
//     from those tokens by DeckTheme.js — nothing is hardcoded.
//   * User content renders as Text.PlainText unless the daemon supplied
//     escaped class markup, which is re-colored against the active theme.
//     The daemon never bakes colors; the shell never trusts markup blindly.
//   * One key dispatcher owns the keyboard while the overlay is open (there
//     is no hidden TextInput to fight for focus), using the same
//     Util.editsFilter vocabulary as the built-in clipboard menu.
//   * Surfaces reuse the shell primitives (BorderSurface, ConfirmDialog,
//     Border.surfaceSpec) so theme authors restyle ClipDeck for free.
Item {
  id: root

  // ---- Injected by the Omarchy shell --------------------------------------
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  // ---- Overlay lifecycle ---------------------------------------------------
  property bool opened: false
  property real reveal: 0 // 0..1 drives the open/close choreography
  property string profile: ""

  // ---- Data ----------------------------------------------------------------
  property var items: []
  property var filteredItems: []
  property int selectedIndex: 0
  property string activeCategory: "all"
  property string searchQuery: ""
  property bool loading: false
  property string conn: "idle" // idle | connecting | online | offline
  property bool isPaused: false
  property string daemonVersion: ""
  property int totalItems: 0
  property real nowMs: Date.now()

  // ---- Interaction state ---------------------------------------------------
  property var selectedIds: [] // multi-select, ordered by pick time
  property var revealedIds: [] // sensitive clips temporarily unmasked
  property string toast: ""
  property bool toastOk: true
  property bool confirmOpen: false
  property string confirmKind: ""
  property string confirmMessage: ""
  property bool transformOpen: false
  property string transformQuery: ""
  property int transformIndex: 0
  property string transformPreview: ""
  property string transformPreviewError: ""

  readonly property var activeItem: selectedIndex >= 0 && selectedIndex < filteredItems.length ? filteredItems[selectedIndex] : null
  readonly property bool hasSelection: selectedIds.length > 0
  readonly property int searchLen: searchQuery.length

  // ---- Theme tokens --------------------------------------------------------
  readonly property color bg: Color.menu.background
  readonly property color fg: Color.menu.text
  readonly property color borderTone: Color.menu.border
  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color muted: Color.muted
  readonly property color scrim: Color.menu.scrim
  readonly property color selFill: Color.menu.selectedBackground
  readonly property color selText: Color.menu.selectedText
  readonly property int radius: Style.cornerRadius
  readonly property string fontFam: Style.font.menuFamily
  readonly property string codeFam: Style.font.family

  readonly property color hairline: Util.alpha(fg, 0.1)
  readonly property color hairlineSoft: Util.alpha(fg, 0.06)
  readonly property color ghostFill: Util.alpha(fg, 0.04)
  readonly property color raisedFill: Util.alpha(fg, 0.07)
  readonly property color onAccent: DeckTheme.onFill(accent)
  readonly property var borderSpec: Border.surfaceSpec("menu", "border", root.borderTone, Math.max(1, Style.space(2)))
  readonly property var syntax: DeckTheme.syntaxPalette(fg, accent, muted, bg)

  readonly property var categories: [
    { id: "all", label: "All" },
    { id: "pinned", label: "Pinned" },
    { id: "color", label: "Colors" },
    { id: "code", label: "Code" },
    { id: "link", label: "Links" },
    { id: "image", label: "Images" },
    { id: "text", label: "Text" }
  ]

  readonly property var transforms: [
    { id: "uppercase", name: "UPPERCASE", group: "Case", desc: "Convert every character to uppercase" },
    { id: "lowercase", name: "lowercase", group: "Case", desc: "Convert every character to lowercase" },
    { id: "title", name: "Title Case", group: "Case", desc: "Capitalize the first letter of every word" },
    { id: "camel", name: "camelCase", group: "Case", desc: "Join words into camelCase" },
    { id: "snake", name: "snake_case", group: "Case", desc: "Join words into snake_case" },
    { id: "kebab", name: "kebab-case", group: "Case", desc: "Join words into kebab-case" },
    { id: "trim", name: "Trim Whitespace", group: "Text", desc: "Drop leading and trailing whitespace" },
    { id: "json_pretty", name: "Format JSON", group: "Data", desc: "Re-indent JSON with two-space nesting" },
    { id: "sort_lines", name: "Sort Lines", group: "Lines", desc: "Sort lines alphabetically" },
    { id: "dedupe_lines", name: "Deduplicate Lines", group: "Lines", desc: "Keep one copy of each line" },
    { id: "base64_encode", name: "Base64 Encode", group: "Encoding", desc: "Encode text as standard Base64" },
    { id: "base64_decode", name: "Base64 Decode", group: "Encoding", desc: "Decode a Base64 string" },
    { id: "url_encode", name: "URL Encode", group: "Encoding", desc: "Percent-encode for URLs" },
    { id: "url_decode", name: "URL Decode", group: "Encoding", desc: "Decode percent-encoded text" },
    { id: "persian_digits_to_latin", name: "Persian Digits to Latin", group: "Persian", desc: "۰۱۲۳… becomes 0123…" },
    { id: "latin_digits_to_persian", name: "Latin Digits to Persian", group: "Persian", desc: "0123… becomes ۰۱۲۳…" },
    { id: "arabic_digits_to_persian", name: "Arabic Digits to Persian", group: "Persian", desc: "٠١٢٣… becomes ۰۱۲۳…" },
    { id: "arabic_to_persian_letters", name: "Arabic Letters to Persian", group: "Persian", desc: "ي and ك become ی and ک" },
    { id: "normalize_zwnj", name: "Normalize ZWNJ", group: "Persian", desc: "Fix نیم‌فاصله around می and ها" },
    { id: "persian_all", name: "Standardize Persian (All)", group: "Persian", desc: "Run every Persian normalization" }
  ]

  readonly property var filteredTransforms: {
    var q = transformQuery.trim().toLowerCase()
    if (q === "") return transforms
    var out = []
    for (var i = 0; i < transforms.length; i++) {
      var t = transforms[i]
      if (t.name.toLowerCase().indexOf(q) !== -1
          || t.group.toLowerCase().indexOf(q) !== -1
          || t.desc.toLowerCase().indexOf(q) !== -1) out.push(t)
    }
    return out
  }

  readonly property var transformCurrent: transformIndex >= 0 && transformIndex < filteredTransforms.length ? filteredTransforms[transformIndex] : null

  // ---- Socket path ----------------------------------------------------------
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string socketPath: root.runtimeDir + "/" + (root.profile === "dev" ? "clipdeck-dev" : "clipdeck") + "/clipdeck.sock"

  // ---- RPC plumbing ---------------------------------------------------------
  property var pending: ({})
  property int reqSeq: 1
  readonly property int rpcTimeoutMs: 8000

  function rpc(method, params, callback) {
    if (!ipc || !ipc.connected) {
      if (callback) callback(null, "daemon offline")
      return
    }
    var id = "r" + (root.reqSeq++) + "-" + Date.now()
    if (callback) root.pending[id] = { cb: callback, at: Date.now() }
    ipc.write(JSON.stringify({ id: id, method: method, params: params === undefined ? null : params }) + "\n")
    ipc.flush()
  }

  function notify(msg, ok) {
    root.toast = msg
    root.toastOk = ok !== false
    toastTimer.restart()
  }

  // ---- Lifecycle ------------------------------------------------------------
  function open(payloadJson) {
    if (payloadJson) {
      try {
        var p = JSON.parse(payloadJson)
        if (p && p.profile) root.profile = p.profile
      } catch (e) {}
    }
    root.opened = true
    root.reveal = 1
    root.searchQuery = ""
    root.activeCategory = "all"
    root.selectedIndex = 0
    root.selectedIds = []
    root.revealedIds = []
    root.transformOpen = false
    root.transformQuery = ""
    root.transformPreview = ""
    root.transformPreviewError = ""
    root.confirmOpen = false
    root.toast = ""
    root.loading = root.items.length === 0
    root.connect()
    root.refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    if (!root.opened) return
    root.opened = false
    root.reveal = 0
    root.transformOpen = false
    root.confirmOpen = false
    root.selectedIds = []
    root.revealedIds = []
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open("{}")
  }

  function connect() {
    if (root.conn === "online") return
    root.conn = "connecting"
    // Quickshell 0.3.1 keeps an errored QLocalSocket alive and ignores any
    // later connected=true write, so a failed attempt can only be retried
    // by recreating the socket object entirely.
    ipcLoader.active = false
    ipcKick.restart()
  }

  // ---- Data flow ------------------------------------------------------------
  function refresh() {
    searchDebounce.restart()
  }

  function runQuery() {
    if (root.conn !== "online") return
    root.loading = true
    var q = root.searchQuery.trim()
    var method = q === "" ? "list" : "search"
    var params = q === "" ? { limit: 200 } : { query: q, limit: 200 }
    root.rpc(method, params, function (res, err) {
      root.loading = false
      if (err || !res) return
      root.items = res.items || []
      root.applyFilter()
    })
    root.rpc("status", null, function (res) {
      if (!res) return
      root.isPaused = res.paused === true
      root.totalItems = res.total_items || 0
      root.daemonVersion = res.version || ""
    })
  }

  function applyFilter() {
    var out = []
    for (var i = 0; i < root.items.length; i++) {
      if (root.matches(root.items[i])) out.push(root.items[i])
    }
    root.filteredItems = out
    if (root.selectedIndex >= out.length) root.selectedIndex = Math.max(0, out.length - 1)
    if (root.selectedIndex < 0) root.selectedIndex = 0
  }

  function matchesFor(item, cat) {
    if (!item) return false
    if (cat === "all") return true
    if (cat === "pinned") return item.pinned === true
    if (cat === "code") return item.type === "code" || item.type === "json"
    if (cat === "text") return item.type === "text" || item.type === "email" || item.type === "phone" || item.type === "number" || item.type === "file" || item.type === "path"
    return item.type === cat
  }

  function matches(item) {
    return root.matchesFor(item, root.activeCategory)
  }

  function countFor(catId) {
    var n = 0
    for (var i = 0; i < root.items.length; i++) {
      if (root.matchesFor(root.items[i], catId)) n++
    }
    return n
  }

  function selectCategory(catId) {
    root.activeCategory = catId
    root.selectedIndex = 0
    root.applyFilter()
  }

  function moveSelection(delta) {
    if (root.filteredItems.length === 0) return
    var n = root.filteredItems.length
    root.selectedIndex = ((root.selectedIndex + delta) % n + n) % n
    itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function selectEdge(last) {
    if (root.filteredItems.length === 0) return
    root.selectedIndex = last ? root.filteredItems.length - 1 : 0
    itemsList.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function isSelected(id) {
    return root.selectedIds.indexOf(id) !== -1
  }

  function toggleSelected(id) {
    var next = root.selectedIds.slice()
    var at = next.indexOf(id)
    if (at === -1) next.push(id)
    else next.splice(at, 1)
    root.selectedIds = next
  }

  function selectAll() {
    var next = []
    for (var i = 0; i < root.filteredItems.length; i++) next.push(root.filteredItems[i].id)
    root.selectedIds = next
    if (next.length > 1) root.notify(next.length + " clips selected — Enter merges them as a new clip", true)
  }

  function isRevealed(id) {
    return root.revealedIds.indexOf(id) !== -1
  }

  function toggleReveal(item) {
    if (!item) return
    var next = root.revealedIds.slice()
    var at = next.indexOf(item.id)
    if (at === -1) next.push(item.id)
    else next.splice(at, 1)
    root.revealedIds = next
  }

  function itemById(id) {
    for (var i = 0; i < root.items.length; i++) if (root.items[i].id === id) return root.items[i]
    return null
  }

  // ---- View helpers -----------------------------------------------------------
  function canOpen(item) {
    if (!item) return false
    return item.type === "link" || item.type === "file" || item.type === "path"
      || item.type === "image" || item.type === "email" || item.type === "phone"
  }

  function isRichPreviewVisible() {
    var it = root.activeItem
    if (it === null) return false
    if (it.type !== "code" && it.type !== "json") return false
    return root.currentPreview() !== ""
  }

  function currentPreview() {
    var item = root.activeItem
    if (!item || !item.rich_preview) return ""
    return DeckTheme.markup(item.rich_preview, root.syntax)
  }

  function plainContent(item) {
    if (!item) return ""
    if (item.sensitive === true && !root.isRevealed(item.id)) {
      return item.masked_content && item.masked_content !== "" ? item.masked_content : "••••••••••••"
    }
    return item.content || ""
  }

  function swatchOf(item) {
    if (!item || item.type !== "color") return "transparent"
    var parsed = DeckTheme.parseColorValue(item.content)
    return parsed.ok ? parsed.hex : Util.alpha(root.fg, 0.08)
  }

  function rowSubtitle(item) {
    if (!item) return ""
    if (item.type === "color") {
      var parsed = DeckTheme.parseColorValue(item.content)
      if (parsed.ok) return parsed.hex + "   " + parsed.rgbText
    }
    if (item.type === "link") {
      var dom = DeckTheme.domainOf(item.content)
      if (dom !== "") return dom + "   " + DeckTheme.clip(item.content.replace(/^https?:\/\//, ""), 64)
    }
    return DeckTheme.clip(item.preview || item.content, 76)
  }

  // ---- Actions ----------------------------------------------------------------
  function pasteItem(item, opts) {
    if (!item) return
    var o = opts || {}
    root.close()
    root.rpc("paste", { id: item.id, plain: o.plain === true, transform: o.transform || "" }, null)
  }

  function copyItem(item, opts) {
    if (!item) return
    var o = opts || {}
    root.rpc("copy", { id: item.id, plain: o.plain === true, transform: o.transform || "" }, function (res, err) {
      if (err) root.notify("Copy failed: " + err, false)
      else root.notify(o.label || "Copied to clipboard", true)
    })
  }

  function pinItem(item) {
    if (!item) return
    var willPin = item.pinned !== true
    item.pinned = willPin
    root.items = root.items.slice()
    root.notify(willPin ? "Pinned — it survives clearing" : "Unpinned", true)
    root.rpc("pin", { id: item.id, pinned: willPin }, function () { root.refresh() })
  }

  function deleteItem(item) {
    if (!item) return
    if (root.selectedIds.length > 1) {
      root.askConfirm("delete-selection")
      return
    }
    root.rpc("delete", { id: item.id }, function (res, err) {
      if (err) root.notify("Delete failed: " + err, false)
      else root.notify("Clip deleted", true)
      root.refresh()
    })
  }

  function askConfirm(kind) {
    root.confirmKind = kind
    if (kind === "clear") {
      root.confirmMessage = "Delete entire unpinned clipboard history? Pinned clips are kept, and this cannot be undone."
    } else if (kind === "delete-selection") {
      root.confirmMessage = "Delete " + root.selectedIds.length + " selected clips? This cannot be undone."
    } else {
      root.confirmMessage = "Are you sure?"
    }
    root.confirmOpen = true
  }

  function runConfirmed() {
    var kind = root.confirmKind
    root.confirmOpen = false
    if (kind === "clear") {
      root.rpc("clear", { include_pinned: false }, function (res, err) {
        if (err) root.notify("Clear failed: " + err, false)
        else root.notify("Cleared unpinned history", true)
        root.refresh()
      })
      return
    }
    if (kind === "delete-selection") {
      var ids = root.selectedIds.slice()
      var count = ids.length
      root.selectedIds = []
      var remaining = count
      for (var i = 0; i < ids.length; i++) {
        root.rpc("delete", { id: ids[i] }, function () {
          remaining--
          if (remaining <= 0) {
            root.notify(count + " clips deleted", true)
            root.refresh()
          }
        })
      }
    }
  }

  function mergeSelection(separator, thenPaste) {
    if (root.selectedIds.length < 2) return
    var ids = root.selectedIds.slice()
    var count = ids.length
    root.selectedIds = []
    root.rpc("merge", { ids: ids, separator: separator, action: thenPaste ? "paste" : "copy" }, function (res, err) {
      if (err) {
        root.notify("Merge failed: " + err, false)
        return
      }
      if (thenPaste) root.close()
      else root.notify(count + " clips merged into one", true)
    })
  }

  function togglePause() {
    root.rpc("pause", { paused: root.isPaused !== true }, function (res, err) {
      if (err || !res) {
        root.notify("Could not toggle capture", false)
        return
      }
      root.isPaused = res.paused === true
      root.notify(root.isPaused ? "Capture paused — incognito" : "Capture resumed", true)
    })
  }

  function openExternal(item) {
    if (!item) return
    var args = ["xdg-open"]
    if (item.type === "image") {
      // Images carry their payload in the blob, not in content.
      var blob = item.blob_path && item.blob_path !== "" ? item.blob_path : item.thumbnail_path
      if (!blob || blob === "") return
      args.push(Util.fileUrl(blob))
    } else if (item.type === "file") {
      // URI lists can hold several files; xdg-open accepts them in one go.
      var paths = String(item.content || "").split("\n")
      for (var i = 0; i < paths.length; i++) {
        var p = paths[i].trim()
        if (p !== "") args.push(Util.fileUrl(p))
      }
      if (args.length === 1) return
    } else if (item.type === "path") {
      if (!item.content) return
      args.push(Util.fileUrl(item.content.trim()))
    } else if (item.type === "email") {
      if (!item.content) return
      args.push("mailto:" + item.content.trim())
    } else if (item.type === "phone") {
      if (!item.content) return
      args.push("tel:" + item.content.replace(/[^+0-9]/g, ""))
    } else {
      if (!item.content) return
      args.push(item.content)
    }
    Util.execArgv(args)
    root.close()
  }

  function openTransformDialog() {
    if (!root.activeItem || root.activeItem.type === "image") return
    root.transformQuery = ""
    root.transformIndex = 0
    root.transformPreview = ""
    root.transformPreviewError = ""
    root.transformOpen = true
    transformPreviewTimer.restart()
  }

  function moveTransform(delta) {
    if (root.filteredTransforms.length === 0) return
    var n = root.filteredTransforms.length
    root.transformIndex = ((root.transformIndex + delta) % n + n) % n
    transformList.positionViewAtIndex(root.transformIndex, ListView.Contain)
    transformPreviewTimer.restart()
  }

  function applyTransform(thenPaste) {
    var t = root.transformCurrent
    var item = root.activeItem
    if (!t || !item) return
    root.transformOpen = false
    if (thenPaste) root.pasteItem(item, { plain: true, transform: t.id })
    else root.copyItem(item, { plain: true, transform: t.id, label: t.name + " copied to clipboard" })
  }

  function quickPaste(index) {
    if (index < 0 || index > 8 || index >= root.filteredItems.length) return
    root.pasteItem(root.filteredItems[index], {})
  }

  // ---- Keyboard ---------------------------------------------------------------
  function handleKey(event) {
    // Mode 1: destructive-action confirmation. The shell's ConfirmDialog
    // owns its own arrow/Enter/Escape choreography.
    if (root.confirmOpen) {
      if (confirmDialog.handleKey(event)) event.accepted = true
      return
    }

    // Mode 2: transform picker.
    if (root.transformOpen) {
      if (event.key === Qt.Key_Escape) {
        if (root.transformQuery !== "") {
          root.transformQuery = ""
          root.transformIndex = 0
          transformPreviewTimer.restart()
        } else {
          root.transformOpen = false
        }
        event.accepted = true
      } else if (event.key === Qt.Key_Up || (event.key === Qt.Key_K && event.modifiers & Qt.ControlModifier)) {
        root.moveTransform(-1)
        event.accepted = true
      } else if (event.key === Qt.Key_Down || (event.key === Qt.Key_J && event.modifiers & Qt.ControlModifier)) {
        root.moveTransform(1)
        event.accepted = true
      } else if (event.key === Qt.Key_PageDown) {
        root.moveTransform(6)
        event.accepted = true
      } else if (event.key === Qt.Key_PageUp) {
        root.moveTransform(-6)
        event.accepted = true
      } else if (Util.editsFilter(event, root.transformQuery)) {
        root.transformQuery = Util.editedFilter(event, root.transformQuery)
        root.transformIndex = 0
        transformPreviewTimer.restart()
        event.accepted = true
      } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
        root.applyTransform((event.modifiers & Qt.ShiftModifier) !== 0)
        event.accepted = true
      } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
        if (root.transformQuery.length < 80) root.transformQuery += event.text
        root.transformIndex = 0
        transformPreviewTimer.restart()
        event.accepted = true
      }
      return
    }

    // Mode 3: the deck itself.
    var ctrl = (event.modifiers & Qt.ControlModifier) !== 0
    var alt = (event.modifiers & Qt.AltModifier) !== 0
    var shift = (event.modifiers & Qt.ShiftModifier) !== 0

    if (event.key === Qt.Key_Escape) {
      if (root.selectedIds.length > 0) root.selectedIds = []
      else if (root.searchQuery !== "") {
        root.searchQuery = ""
        root.refresh()
      } else root.close()
      event.accepted = true
      return
    }

    if (event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)) {
      root.moveSelection(-1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)) {
      root.moveSelection(1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageUp) {
      root.moveSelection(-6)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_PageDown) {
      root.moveSelection(6)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Home) {
      root.selectEdge(false)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_End) {
      root.selectEdge(true)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
      var order = ["all", "pinned", "color", "code", "link", "image", "text"]
      var at = order.indexOf(root.activeCategory)
      if (at === -1) at = 0
      var step = (event.key === Qt.Key_Backtab || shift) ? -1 : 1
      root.selectCategory(order[(at + step + order.length) % order.length])
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
      if (root.conn !== "online") root.connect()
      else if (alt && root.canOpen(root.activeItem)) root.openExternal(root.activeItem)
      else if (root.selectedIds.length > 1) root.mergeSelection("\n", shift)
      else if (ctrl) root.copyItem(root.activeItem, { plain: shift })
      else root.pasteItem(root.activeItem, { plain: shift })
      event.accepted = true
      return
    }
    if (alt && event.key >= Qt.Key_1 && event.key <= Qt.Key_9) {
      root.quickPaste(event.key - Qt.Key_1)
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Space && (ctrl || root.searchQuery === "")) {
      if (root.activeItem) root.toggleSelected(root.activeItem.id)
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_A) {
      root.selectAll()
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_C) {
      root.copyItem(root.activeItem, { plain: shift })
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_P) {
      root.pinItem(root.activeItem)
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_T) {
      root.openTransformDialog()
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_R) {
      if (root.activeItem) root.toggleReveal(root.activeItem)
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_I) {
      root.togglePause()
      event.accepted = true
      return
    }
    if (event.key === Qt.Key_Delete) {
      if (shift) root.askConfirm("clear")
      else root.deleteItem(root.activeItem)
      event.accepted = true
      return
    }
    if (ctrl && event.key === Qt.Key_F) {
      root.notify("Every keystroke already searches — just start typing", true)
      event.accepted = true
      return
    }
    if (Util.editsFilter(event, root.searchQuery)) {
      root.searchQuery = Util.editedFilter(event, root.searchQuery)
      root.refresh()
      event.accepted = true
      return
    }
    if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127 && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
      if (root.searchQuery.length < 200) root.searchQuery += event.text
      root.refresh()
      event.accepted = true
      return
    }
  }

  // ---- Timers ---------------------------------------------------------------
  Timer {
    id: searchDebounce
    interval: 90
    repeat: false
    onTriggered: root.runQuery()
  }

  Timer {
    id: toastTimer
    interval: 2400
    repeat: false
    onTriggered: root.toast = ""
  }

  Timer {
    id: clockTimer
    interval: 1000
    repeat: true
    running: root.opened
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: pendingWatchdog
    interval: 4000
    repeat: true
    running: root.opened
    onTriggered: {
      var now = Date.now()
      var stale = []
      for (var id in root.pending) {
        if (now - root.pending[id].at > root.rpcTimeoutMs) stale.push(id)
      }
      if (stale.length > 0) {
        for (var i = 0; i < stale.length; i++) delete root.pending[stale[i]]
        if (root.conn === "online") root.notify("Daemon did not answer — run clipdeck doctor to diagnose", false)
      }
    }
  }

  Timer {
    id: retryTimer
    interval: 2500
    repeat: true
    running: root.opened && root.conn === "offline"
    onTriggered: root.connect()
  }

  Timer {
    id: transformPreviewTimer
    interval: 120
    repeat: false
    onTriggered: {
      var t = root.transformCurrent
      var item = root.activeItem
      if (!t || !item) {
        root.transformPreview = ""
        return
      }
      root.rpc("transform", { id: item.id, action: t.id }, function (res, err) {
        if (err || !res) {
          root.transformPreview = ""
          root.transformPreviewError = err || "Transform failed"
          return
        }
        root.transformPreviewError = ""
        root.transformPreview = DeckTheme.clip(res.text || "", 900)
      })
    }
  }

  // ---- Daemon connection ------------------------------------------------------
  // The socket lives behind a Loader so retries can recreate it: a Socket
  // whose first connection attempt fails never connects again in Quickshell
  // 0.3.1 (the dead QLocalSocket is kept internally and later
  // connected=true writes are no-ops).
  readonly property var ipc: ipcLoader.item

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
      id: ipcSock
      path: root.socketPath
      connected: true

      onConnectionStateChanged: {
        if (ipcSock.connected) {
          root.conn = "online"
          root.refresh()
        } else if (root.conn === "online") {
          root.conn = "offline"
        }
      }

      onError: function (error) {
        root.conn = "offline"
      }

      parser: SplitParser {
        splitMarker: "\n"
        onRead: function (line) { root.handleMessage(line) }
      }
    }
  }

  function handleMessage(line) {
    var text = String(line || "").trim()
    if (text === "") return
    var msg
    try {
      msg = JSON.parse(text)
    } catch (e) {
      return
    }
    if (msg.event) {
      root.handleEvent(msg.event, msg.data)
      return
    }
    if (msg.id && root.pending[msg.id]) {
      var entry = root.pending[msg.id]
      delete root.pending[msg.id]
      entry.cb(msg.result !== undefined ? msg.result : null, msg.error ? (msg.error.message || "request failed") : null)
    }
  }

  function handleEvent(event, data) {
    if (event === "item_added" || event === "item_deleted" || event === "history_cleared" || event === "items_purged") {
      root.refresh()
      return
    }
    if (event === "pin_changed") {
      if (data && data.id) {
        var item = root.itemById(data.id)
        if (item) item.pinned = data.pinned === true
        root.items = root.items.slice()
      }
      return
    }
    if (event === "pause_changed" && data) {
      root.isPaused = data.paused === true
      root.notify(root.isPaused ? "Capture paused — incognito" : "Capture resumed", true)
    }
  }

  // ---- Window & surfaces ------------------------------------------------------
  PanelWindow {
    id: panel
    visible: root.reveal > 0.01
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "clipdeck-overlay"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // Scrim: the themed menu dim, click anywhere to dismiss.
    Rectangle {
      anchors.fill: parent
      color: root.scrim
      opacity: root.reveal
      MouseArea {
        anchors.fill: parent
        onClicked: root.close()
      }
    }

    // The deck card — a BorderSurface so the theme's border style applies
    // exactly like the built-in menu and clipboard surfaces.
    BorderSurface {
      id: card
      anchors.centerIn: parent
      width: Math.min(Style.space(1060), panel.width - Style.gapsOut * 4)
      height: Math.min(Style.space(700), panel.height - Style.gapsOut * 4)
      radius: root.radius
      color: root.bg
      borderSpec: root.borderSpec
      opacity: root.reveal
      scale: 0.985 + 0.015 * root.reveal
      clip: true

      // Swallow clicks so the scrim dismiss only fires outside the deck.
      MouseArea { anchors.fill: parent }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function (event) {
          root.handleKey(event)
        }

        // ================= Header ==========================================
        Item {
          id: header
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          height: Style.space(64)

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.hairline
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(18)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(12)

            // Brand mark: painted (clipboard lines), not icon-font dependent.
            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              implicitWidth: Style.space(30)
              implicitHeight: Style.space(30)
              radius: Math.min(root.radius, Style.space(9))
              color: root.accent

              Column {
                anchors.centerIn: parent
                spacing: Style.space(3)

                Rectangle { width: Style.space(14); height: Math.max(1, Style.space(2)); radius: height / 2; color: Util.alpha(root.onAccent, 0.92) }
                Rectangle { width: Style.space(14); height: Math.max(1, Style.space(2)); radius: height / 2; color: Util.alpha(root.onAccent, 0.7) }
                Rectangle { width: Style.space(9); height: Math.max(1, Style.space(2)); radius: height / 2; color: Util.alpha(root.onAccent, 0.45) }
              }
            }

            ColumnLayout {
              Layout.alignment: Qt.AlignVCenter
              spacing: 0

              Text {
                text: "ClipDeck"
                font.family: root.fontFam
                font.pixelSize: Style.font.title
                font.bold: true
                color: root.fg
              }

              Text {
                text: root.searchLen > 0
                  ? "Filtering " + root.filteredItems.length + " of " + root.items.length
                  : root.totalItems + " clips · instant search"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                color: Util.alpha(root.fg, 0.55)
              }
            }

            // Capture state: a bare dot + lowercase label, click to
            // pause/resume. No pill chrome — the state is information, not
            // decoration.
            Item {
              Layout.alignment: Qt.AlignVCenter
              implicitWidth: captureRow.implicitWidth
              implicitHeight: Math.max(captureRow.implicitHeight, Style.space(22))

              Row {
                id: captureRow
                anchors.centerIn: parent
                spacing: Style.space(5)

                Rectangle {
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(6)
                  height: Style.space(6)
                  radius: width / 2
                  color: root.isPaused ? root.urgent : Util.alpha(root.accent, 0.9)
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: root.isPaused ? "paused" : "recording"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  color: root.isPaused ? root.urgent : Util.alpha(root.fg, 0.5)
                }
              }

              MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.togglePause()
              }
            }

            // Search surface: a rendered field, not a TextInput — the key
            // dispatcher owns input, so focus can never drift.
            Rectangle {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              Layout.preferredHeight: Style.space(32)
              radius: Math.min(root.radius, height / 2)
              color: root.ghostFill

              Item {
                anchors.fill: parent
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(10)

                Text {
                  id: searchText
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width
                  text: root.searchQuery
                  visible: root.searchQuery !== ""
                  font.family: root.fontFam
                  font.pixelSize: Style.font.body
                  color: root.fg
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  visible: root.searchQuery === ""
                  text: "Type to search…   Backspace edits, Ctrl+U clears"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.body
                  color: Util.alpha(root.fg, 0.42)
                }

                // Blinking caret after the query.
                Rectangle {
                  id: caret
                  visible: root.searchQuery !== ""
                  x: Math.min(parent.width - width, searchText.implicitWidth + Style.space(2))
                  anchors.verticalCenter: parent.verticalCenter
                  width: Math.max(1, Style.space(1))
                  height: Math.max(10, Style.font.body + 4)
                  color: root.accent

                  SequentialAnimation on opacity {
                    running: caret.visible && root.opened
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 480 }
                    NumberAnimation { to: 1.0; duration: 480 }
                  }
                }
              }
            }

            // Shown / selected count — plain text, no pill.
            Text {
              id: countText
              Layout.alignment: Qt.AlignVCenter
              text: root.hasSelection ? root.selectedIds.length + " selected" : root.filteredItems.length + " shown"
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: root.hasSelection ? root.accent : Util.alpha(root.fg, 0.45)
              Behavior on color { ColorAnimation { duration: 90 } }
            }

            // Close.
            Rectangle {
              Layout.alignment: Qt.AlignVCenter
              implicitWidth: Style.space(24)
              implicitHeight: Style.space(24)
              radius: Math.min(root.radius, height / 2)
              color: closeMouse.containsMouse ? root.raisedFill : "transparent"

              Text {
                anchors.centerIn: parent
                text: "×"
                font.family: root.fontFam
                font.pixelSize: Style.font.subtitle
                color: Util.alpha(root.fg, 0.6)
              }

              MouseArea {
                id: closeMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
              }
            }
          }
        }

        // ================= Category rail ===================================
        Item {
          id: rail
          anchors.top: header.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          height: chips.implicitHeight + Style.space(16)

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: root.hairlineSoft
          }

          Row {
            id: chips
            anchors.left: parent.left
            anchors.leftMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

            Repeater {
              model: root.categories

              DeckChip {
                required property var modelData
                label: modelData.label
                count: root.countFor(modelData.id)
                active: root.activeCategory === modelData.id
                onClicked: root.selectCategory(modelData.id)
              }
            }
          }

          Row {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(16)
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.loading
              text: "syncing…"
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: Util.alpha(root.fg, 0.5)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "Tab switches category"
              font.family: root.fontFam
              font.pixelSize: Style.font.caption
              color: Util.alpha(root.fg, 0.38)
            }
          }
        }

        // ================= Body: list + inspector ==========================
        RowLayout {
          id: body
          anchors.top: rail.bottom
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: footer.top
          spacing: 0

          // -------- Left: the clip list ------------------------------------
          Item {
            Layout.fillHeight: true
            Layout.preferredWidth: Math.round(Math.max(Style.space(340), Math.min(Style.space(470), card.width * 0.42)))

            ListView {
              id: itemsList
              anchors.fill: parent
              anchors.leftMargin: Style.space(10)
              anchors.rightMargin: Style.space(8)
              anchors.topMargin: Style.space(8)
              anchors.bottomMargin: Style.space(4)
              model: root.filteredItems
              clip: true
              spacing: Style.space(3)
              boundsBehavior: Flickable.StopAtBounds

              delegate: Rectangle {
                id: row
                required property var modelData
                required property int index

                readonly property bool current: root.selectedIndex === row.index
                readonly property bool chosen: root.isSelected(row.modelData.id)
                readonly property bool hot: rowMouse.containsMouse
                readonly property bool isColor: row.modelData.type === "color"
                readonly property bool isImage: row.modelData.type === "image"
                readonly property bool hasThumb: row.isImage && (row.modelData.thumbnail_path || row.modelData.blob_path)
                readonly property bool sensitiveLocked: row.modelData.sensitive === true && !root.isRevealed(row.modelData.id)
                readonly property var colorInfo: row.isColor ? DeckTheme.parseColorValue(row.modelData.content) : null

                width: itemsList.width
                height: Style.space(50)
                radius: Math.min(root.radius, Style.space(8))
                // Minimal selection language: fills and the spine only —
                // no borders, so the list reads as one quiet surface.
                color: row.chosen
                  ? Util.alpha(root.accent, 0.10)
                  : (row.current ? root.selFill : (row.hot ? root.ghostFill : "transparent"))

                Behavior on color { ColorAnimation { duration: 90; easing.type: Easing.OutCubic } }

                // Accent spine on the current row.
                Rectangle {
                  anchors.left: parent.left
                  anchors.leftMargin: Style.space(2)
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(3)
                  height: parent.height - Style.space(14)
                  radius: width / 2
                  color: row.current || row.chosen ? root.accent : "transparent"
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(9)

                  // Selection checkbox — passive indicator; hit-testing is
                  // done by the row's single MouseArea below (no nested areas).
                  Rectangle {
                    id: checkBox
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Style.space(16)
                    Layout.preferredHeight: Style.space(16)
                    visible: root.hasSelection || row.hot
                    radius: Style.space(4)
                    color: row.chosen ? root.accent : "transparent"
                    border.color: row.chosen ? root.accent : Util.alpha(root.fg, 0.4)
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      visible: row.chosen
                      text: "✓"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.onAccent
                    }
                  }

                  // Type badge: color swatch, thumbnail, or three-letter tag.
                  Rectangle {
                    Layout.alignment: Qt.AlignVCenter
                    Layout.preferredWidth: Style.space(32)
                    Layout.preferredHeight: Style.space(30)
                    radius: Math.min(root.radius, Style.space(7))
                    color: row.isColor && row.colorInfo.ok
                      ? row.colorInfo.hex
                      : (row.hasThumb ? "transparent" : root.raisedFill)
                    clip: true

                    Text {
                      anchors.centerIn: parent
                      visible: !row.hasThumb
                      text: DeckTheme.tag(row.modelData.type)
                      font.family: root.codeFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 0.5
                      color: row.isColor && row.colorInfo.ok
                        ? row.colorInfo.readable
                        : Util.alpha(root.fg, 0.8)
                    }

                    Image {
                      anchors.fill: parent
                      visible: row.hasThumb
                      source: row.hasThumb ? Util.fileUrl(row.modelData.thumbnail_path || row.modelData.blob_path) : ""
                      fillMode: Image.PreserveAspectCrop
                      asynchronous: true
                      sourceSize.width: 72
                      sourceSize.height: 72
                    }
                  }

                  // Text block.
                  ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        visible: row.modelData.pinned === true
                        text: "PINNED"
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: root.accent
                      }

                      Text {
                        visible: row.modelData.sensitive === true
                        text: row.sensitiveLocked ? "SENSITIVE" : "SENSITIVE · revealed"
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        font.bold: true
                        color: row.sensitiveLocked ? root.urgent : Util.alpha(root.urgent, 0.6)
                      }

                      Text {
                        Layout.fillWidth: true
                        text: row.modelData.source_app && row.modelData.source_app !== "" ? row.modelData.source_app : "clipboard"
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        color: row.current ? Util.alpha(root.selText, 0.75) : Util.alpha(root.fg, 0.5)
                        elide: Text.ElideRight
                      }

                      Text {
                        text: row.modelData.expires_at > 0
                          ? "expires " + DeckTheme.untilLabel(row.modelData.expires_at, root.nowMs)
                          : DeckTheme.timeAgo(row.modelData.created_at, root.nowMs)
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        color: row.modelData.expires_at > 0 ? Util.alpha(root.urgent, 0.85) : Util.alpha(root.fg, 0.45)
                      }
                    }

                    Text {
                      Layout.fillWidth: true
                      text: root.rowSubtitle(row.modelData)
                      font.family: row.modelData.type === "code" || row.modelData.type === "json" ? root.codeFam : root.fontFam
                      font.pixelSize: Style.font.body
                      color: row.current ? root.fg : Util.alpha(root.fg, 0.92)
                      elide: Text.ElideRight
                      textFormat: Text.PlainText
                      maximumLineCount: 1
                      horizontalAlignment: DeckTheme.isRTL(text) ? Text.AlignRight : Text.AlignLeft
                    }
                  }

                  // Quick-paste digit for the first nine rows — bare text.
                  Text {
                    Layout.alignment: Qt.AlignVCenter
                    visible: row.index < 9 && (row.hot || row.current)
                    text: row.index + 1
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(root.fg, 0.4)
                  }
                }

                MouseArea {
                  id: rowMouse
                  anchors.fill: parent
                  hoverEnabled: true
                  acceptedButtons: Qt.LeftButton
                  onClicked: function (mouse) {
                    // Clicking the checkbox — or Ctrl-clicking anywhere —
                    // toggles multi-select; anything else moves the cursor.
                    var onCheckbox = checkBox.visible && mouse.x <= checkBox.x + checkBox.width + Style.space(8)
                    if (onCheckbox || (mouse.modifiers & Qt.ControlModifier) !== 0) {
                      root.toggleSelected(row.modelData.id)
                    } else {
                      root.selectedIndex = row.index
                    }
                  }
                  onDoubleClicked: {
                    root.pasteItem(row.modelData, {})
                  }
                }
              }
            }

            // Thin scroll indicator (keyboard is primary; this hints there is
            // more below). Sibling of the ListView, so it never scrolls.
            Rectangle {
              id: scrollThumb
              visible: itemsList.contentHeight > itemsList.height + 1
              width: Style.space(3)
              radius: width / 2
              color: Util.alpha(root.fg, 0.25)
              x: itemsList.x + itemsList.width - width - Style.space(2)
              height: Math.max(Style.space(28), itemsList.height * (itemsList.height / Math.max(1, itemsList.contentHeight)))
              y: itemsList.y + (itemsList.contentY / Math.max(1, itemsList.contentHeight - itemsList.height)) * (itemsList.height - height)
            }

            // Empty / loading state.
            Column {
              anchors.centerIn: parent
              width: Math.min(parent.width - Style.space(40), Style.space(360))
              spacing: Style.space(8)
              visible: root.filteredItems.length === 0 && root.conn === "online"

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.loading
                  ? "Loading history…"
                  : (root.searchQuery !== "" ? "Nothing matches “" + DeckTheme.clip(root.searchQuery, 28) + "”" : "No clips captured yet")
                font.family: root.fontFam
                font.pixelSize: Style.font.title
                color: Util.alpha(root.fg, 0.7)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                textFormat: Text.PlainText
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.searchQuery !== ""
                  ? "Backspace edits the filter · Ctrl+U clears it"
                  : "Copy something and it lands here instantly"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                color: Util.alpha(root.fg, 0.45)
                horizontalAlignment: Text.AlignHCenter
              }
            }
          }

          // Divider between the panes.
          Rectangle {
            Layout.fillHeight: true
            Layout.topMargin: Style.space(8)
            Layout.bottomMargin: Style.space(8)
            Layout.preferredWidth: 1
            color: root.hairline
          }

          // -------- Right: inspector ----------------------------------------
          Item {
            id: inspector
            Layout.fillWidth: true
            Layout.fillHeight: true

            // Offline state replaces the whole pane.
            Column {
              anchors.centerIn: parent
              width: Math.min(parent.width - Style.space(60), Style.space(420))
              spacing: Style.space(10)
              visible: root.conn !== "online"

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                implicitWidth: offlinePill.implicitWidth + Style.space(18)
                implicitHeight: Style.space(26)
                radius: height / 2
                color: root.conn === "connecting" ? Util.alpha(root.accent, 0.14) : Util.alpha(root.urgent, 0.16)

                Text {
                  id: offlinePill
                  anchors.centerIn: parent
                  text: root.conn === "connecting" ? "CONNECTING" : "OFFLINE"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  color: root.conn === "connecting" ? root.accent : root.urgent
                }
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.conn === "connecting" ? "Connecting to clipdeckd…" : "clipdeckd is not reachable"
                font.family: root.fontFam
                font.pixelSize: Style.font.title
                font.bold: true
                color: root.fg
                horizontalAlignment: Text.AlignHCenter
              }

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.conn !== "connecting"
                text: "Start the daemon, then retry — the deck also reconnects on its own:"
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                color: Util.alpha(root.fg, 0.6)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
              }

              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.conn !== "connecting"
                implicitWidth: offlineCmd.implicitWidth + Style.space(24)
                implicitHeight: Style.space(30)
                radius: Math.min(root.radius, height / 2)
                color: root.ghostFill

                Text {
                  id: offlineCmd
                  anchors.centerIn: parent
                  text: "systemctl --user start clipdeckd"
                  font.family: root.codeFam
                  font.pixelSize: Style.font.caption
                  color: Util.alpha(root.fg, 0.8)
                }

                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: {
                    // The daemon is unreachable by definition here, so copy
                    // via a detached helper instead of an RPC.
                    Quickshell.execDetached(["bash", "-lc", "printf '%s' 'systemctl --user start clipdeckd' | wl-copy"])
                    root.notify("Command copied — paste it in a terminal", true)
                  }
                }
              }

              DeckButton {
                anchors.horizontalCenter: parent.horizontalCenter
                variant: "primary"
                label: "Retry connection"
                hint: "Enter"
                visible: root.conn !== "connecting"
                onClicked: root.connect()
              }
            }

            // Inspector content for a selected clip.
            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(16)
              spacing: Style.space(12)
              visible: root.conn === "online" && root.activeItem !== null

              // ---- Hero row
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(10)

                Rectangle {
                  Layout.alignment: Qt.AlignVCenter
                  implicitWidth: Style.space(34)
                  implicitHeight: Style.space(34)
                  radius: Math.min(root.radius, Style.space(8))
                  color: root.activeItem !== null && root.activeItem.type === "color" ? root.swatchOf(root.activeItem) : root.raisedFill

                  Text {
                    anchors.centerIn: parent
                    visible: root.activeItem === null || root.activeItem.type !== "color"
                    text: DeckTheme.tag(root.activeItem !== null ? root.activeItem.type : "text")
                    font.family: root.codeFam
                    font.pixelSize: Style.font.body
                    font.bold: true
                    color: Util.alpha(root.fg, 0.85)
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  spacing: 0

                  RowLayout {
                    spacing: Style.space(8)

                    Text {
                      text: DeckTheme.typeName(root.activeItem !== null ? root.activeItem.type : "")
                      font.family: root.fontFam
                      font.pixelSize: Style.font.title
                      font.bold: true
                      color: root.fg
                    }

                    Text {
                      visible: root.activeItem !== null && root.activeItem.sensitive === true
                      text: "SECRET"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.urgent
                    }

                    Text {
                      visible: root.activeItem !== null && root.activeItem.expires_at > 0
                      text: root.activeItem !== null && root.activeItem.expires_at > 0
                        ? "expires in " + DeckTheme.untilLabel(root.activeItem.expires_at, root.nowMs)
                        : ""
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      color: Util.alpha(root.urgent, 0.85)
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: {
                      var it = root.activeItem
                      if (it === null) return ""
                      var parts = []
                      parts.push(it.source_app && it.source_app !== "" ? it.source_app : "clipboard")
                      parts.push(DeckTheme.timeAgo(it.created_at, root.nowMs))
                      parts.push(DeckTheme.bytes(it.size_bytes))
                      if (it.mime && it.mime !== "text/plain") parts.push(it.mime)
                      return parts.join("   ·   ")
                    }
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(root.fg, 0.55)
                    elide: Text.ElideRight
                  }
                }

                DeckButton {
                  Layout.alignment: Qt.AlignVCenter
                  compact: true
                  label: root.activeItem !== null && root.activeItem.pinned === true ? "Pinned" : "Pin"
                  hint: "Ctrl+P"
                  active: root.activeItem !== null && root.activeItem.pinned === true
                  onClicked: root.pinItem(root.activeItem)
                }

                DeckButton {
                  Layout.alignment: Qt.AlignVCenter
                  compact: true
                  variant: "danger"
                  label: "Delete"
                  hint: "Del"
                  onClicked: root.deleteItem(root.activeItem)
                }
              }

              // ---- Content viewport
              Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Math.min(root.radius, Style.space(10))
                color: root.ghostFill
                clip: true

                // 1. Color: hero swatch plus copy-ready representations.
                ColumnLayout {
                  anchors.centerIn: parent
                  spacing: Style.space(10)
                  visible: root.activeItem !== null && root.activeItem.type === "color"

                  Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Style.space(240)
                    Layout.preferredHeight: Style.space(110)
                    radius: Math.min(root.radius, Style.space(12))
                    color: root.swatchOf(root.activeItem)

                    Text {
                      anchors.centerIn: parent
                      text: root.activeItem !== null && DeckTheme.parseColorValue(root.activeItem.content).ok
                        ? DeckTheme.parseColorValue(root.activeItem.content).hex
                        : ""
                      font.family: root.codeFam
                      font.pixelSize: Style.font.heading
                      font.bold: true
                      font.letterSpacing: 1.0
                      color: root.activeItem !== null && DeckTheme.parseColorValue(root.activeItem.content).ok
                        ? DeckTheme.parseColorValue(root.activeItem.content).readable
                        : root.fg
                    }
                  }

                  Repeater {
                    model: {
                      var it = root.activeItem
                      if (it === null || it.type !== "color") return []
                      var parsed = DeckTheme.parseColorValue(it.content)
                      if (!parsed.ok) return []
                      var rows = [
                        { label: "HEX", value: parsed.hex },
                        { label: "RGB", value: parsed.rgbText },
                        { label: "HSL", value: parsed.hslText }
                      ]
                      if (parsed.alphaText !== "") rows.push({ label: "ALPHA", value: parsed.alphaText })
                      return rows
                    }

                    Rectangle {
                      id: fmtRow
                      required property var modelData
                      Layout.alignment: Qt.AlignHCenter
                      Layout.preferredWidth: Style.space(240)
                      implicitHeight: Style.space(30)
                      radius: Math.min(root.radius, height / 2)
                      color: fmtMouse.containsMouse ? root.raisedFill : "transparent"

                      RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Style.space(10)
                        anchors.rightMargin: Style.space(10)
                        spacing: Style.space(8)

                        Text {
                          text: fmtRow.modelData.label
                          font.family: root.fontFam
                          font.pixelSize: Style.font.caption
                          color: Util.alpha(root.fg, 0.5)
                        }

                        Text {
                          Layout.fillWidth: true
                          text: fmtRow.modelData.value
                          font.family: root.codeFam
                          font.pixelSize: Style.font.body
                          color: root.fg
                          elide: Text.ElideRight
                          textFormat: Text.PlainText
                        }

                        Text {
                          text: fmtMouse.containsMouse ? "copy" : ""
                          font.family: root.fontFam
                          font.pixelSize: Style.font.caption
                          color: root.accent
                        }
                      }

                      MouseArea {
                        id: fmtMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          Quickshell.execDetached(["bash", "-lc", "printf '%s' " + Util.shellQuote(fmtRow.modelData.value) + " | wl-copy"])
                          root.notify(fmtRow.modelData.label + " copied", true)
                        }
                      }
                    }
                  }
                }

                // 2. Image: fit view plus dimension chip.
                Item {
                  anchors.fill: parent
                  anchors.margins: Style.space(12)
                  visible: root.activeItem !== null && root.activeItem.type === "image"

                  Image {
                    anchors.fill: parent
                    source: root.activeItem !== null && (root.activeItem.blob_path || root.activeItem.thumbnail_path)
                      ? Util.fileUrl(root.activeItem.blob_path || root.activeItem.thumbnail_path)
                      : ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                  }

                  Rectangle {
                    visible: root.activeItem !== null && DeckTheme.imageDims(root.activeItem.preview) !== ""
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    implicitWidth: dimsText.implicitWidth + Style.space(14)
                    implicitHeight: Style.space(22)
                    radius: height / 2
                    color: Util.alpha(root.bg, 0.75)

                    Text {
                      id: dimsText
                      anchors.centerIn: parent
                      text: root.activeItem !== null ? DeckTheme.imageDims(root.activeItem.preview) : ""
                      font.family: root.codeFam
                      font.pixelSize: Style.font.caption
                      color: Util.alpha(root.fg, 0.85)
                    }
                  }
                }

                // 3. Link: domain chip + full URL.
                ColumnLayout {
                  anchors.centerIn: parent
                  width: Math.min(parent.width - Style.space(48), Style.space(520))
                  spacing: Style.space(12)
                  visible: root.activeItem !== null && root.activeItem.type === "link"

                  Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: linkDomain.implicitWidth + Style.space(18)
                    implicitHeight: Style.space(26)
                    radius: height / 2
                    color: Util.alpha(root.accent, 0.14)

                    Text {
                      id: linkDomain
                      anchors.centerIn: parent
                      text: root.activeItem !== null ? DeckTheme.domainOf(root.activeItem.content) : ""
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      color: root.accent
                    }
                  }

                  Text {
                    Layout.fillWidth: true
                    text: root.activeItem !== null ? root.activeItem.content : ""
                    font.family: root.codeFam
                    font.pixelSize: Style.font.body
                    color: root.fg
                    wrapMode: Text.WrapAnywhere
                    horizontalAlignment: Text.AlignHCenter
                    textFormat: Text.PlainText
                    maximumLineCount: 4
                    elide: Text.ElideRight
                  }

                  Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Alt+Enter opens it · Ctrl+C copies the URL"
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(root.fg, 0.45)
                  }
                }

                // 4. Code / JSON: themed rich text with gutter numbers.
                Flickable {
                  id: codeScroll
                  anchors.fill: parent
                  anchors.margins: Style.space(10)
                  visible: root.isRichPreviewVisible()
                  contentWidth: Math.max(width, codeText.paintedWidth)
                  contentHeight: Math.max(height, codeText.paintedHeight)
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Text {
                    id: codeText
                    text: root.currentPreview()
                    textFormat: Text.RichText
                    font.family: root.codeFam
                    font.pixelSize: Style.font.body
                    wrapMode: Text.NoWrap
                    color: root.fg
                  }
                }

                // 5. Plain text (strict): sensitive masking applies here.
                Flickable {
                  id: plainScroll
                  anchors.fill: parent
                  anchors.margins: Style.space(14)
                  visible: root.activeItem !== null
                    && root.activeItem.type !== "image"
                    && root.activeItem.type !== "color"
                    && root.activeItem.type !== "link"
                    && !root.isRichPreviewVisible()
                  contentWidth: width
                  contentHeight: plainText.paintedHeight
                  clip: true
                  boundsBehavior: Flickable.StopAtBounds

                  Text {
                    id: plainText
                    width: plainScroll.width
                    text: root.plainContent(root.activeItem)
                    font.family: DeckTheme.isRTL(text) ? root.codeFam : root.fontFam
                    font.pixelSize: Style.font.body
                    lineHeight: DeckTheme.isRTL(text) ? 1.5 : 1.25
                    color: root.fg
                    textFormat: Text.PlainText
                    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    horizontalAlignment: DeckTheme.isRTL(text) ? Text.AlignRight : Text.AlignLeft
                  }
                }

                // Masked-secret scrim with a reveal affordance.
                Rectangle {
                  visible: root.activeItem !== null && root.activeItem.sensitive === true && !root.isRevealed(root.activeItem.id)
                  anchors.fill: parent
                  color: Util.alpha(root.bg, 0.82)

                  Column {
                    anchors.centerIn: parent
                    spacing: Style.space(10)

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "SENSITIVE"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      font.letterSpacing: 1.4
                      color: root.urgent
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: "Content hidden"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.title
                      font.bold: true
                      color: root.fg
                    }

                    Text {
                      anchors.horizontalCenter: parent.horizontalCenter
                      text: root.activeItem !== null && root.activeItem.expires_at > 0
                        ? "Auto-expires in " + DeckTheme.untilLabel(root.activeItem.expires_at, root.nowMs)
                        : "Passwords, keys and tokens never render by accident"
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      color: Util.alpha(root.fg, 0.55)
                    }

                    DeckButton {
                      anchors.horizontalCenter: parent.horizontalCenter
                      variant: "primary"
                      label: root.activeItem !== null && root.isRevealed(root.activeItem.id) ? "Hide again" : "Reveal content"
                      hint: "Ctrl+R"
                      onClicked: root.toggleReveal(root.activeItem)
                    }
                  }
                }
              }

              // ---- Action bar: multi-select mode
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)
                visible: root.selectedIds.length > 1

                DeckButton {
                  compact: true
                  variant: "primary"
                  label: "Merge " + root.selectedIds.length
                  hint: "Enter"
                  onClicked: root.mergeSelection("\n", false)
                }

                DeckButton {
                  compact: true
                  label: "Merge & paste"
                  hint: "Shift+Enter"
                  onClicked: root.mergeSelection("\n", true)
                }

                DeckButton {
                  compact: true
                  label: "space"
                  onClicked: root.mergeSelection(" ", false)
                }

                DeckButton {
                  compact: true
                  label: "comma"
                  onClicked: root.mergeSelection(", ", false)
                }

                DeckButton {
                  compact: true
                  variant: "danger"
                  label: "Delete"
                  hint: "Del"
                  onClicked: root.askConfirm("delete-selection")
                }

                DeckButton {
                  compact: true
                  label: "Clear"
                  hint: "Esc"
                  onClicked: root.selectedIds = []
                }
              }

              // ---- Action bar: single clip
              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)
                visible: root.selectedIds.length <= 1

                DeckButton {
                  compact: true
                  variant: "primary"
                  label: "Paste"
                  hint: "Enter"
                  onClicked: root.pasteItem(root.activeItem, {})
                }

                DeckButton {
                  compact: true
                  label: "Plain"
                  hint: "Shift+Enter"
                  onClicked: root.pasteItem(root.activeItem, { plain: true })
                }

                DeckButton {
                  compact: true
                  label: "Copy"
                  hint: "Ctrl+C"
                  onClicked: root.copyItem(root.activeItem, {})
                }

                DeckButton {
                  compact: true
                  visible: root.canOpen(root.activeItem)
                  label: "Open"
                  hint: "Alt+Enter"
                  onClicked: root.openExternal(root.activeItem)
                }

                DeckButton {
                  compact: true
                  visible: root.activeItem !== null && root.activeItem.type !== "image"
                  label: "Transform"
                  hint: "Ctrl+T"
                  onClicked: root.openTransformDialog()
                }
              }
            }

            // Nothing selected.
            Column {
              anchors.centerIn: parent
              spacing: Style.space(8)
              visible: root.conn === "online" && root.activeItem === null

              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Pick a clip to inspect and act on it"
                font.family: root.fontFam
                font.pixelSize: Style.font.body
                color: Util.alpha(root.fg, 0.55)
              }
            }
          }
        }

        // ================= Footer ==========================================
        Item {
          id: footer
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.space(38)

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: root.hairline
          }

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Style.space(16)
            anchors.rightMargin: Style.space(16)
            spacing: Style.space(12)

            Row {
              Layout.alignment: Qt.AlignVCenter
              Layout.fillWidth: true
              spacing: Style.space(10)
              clip: true

              Repeater {
                model: [
                  { key: "Enter", label: "paste" },
                  { key: "Ctrl+C", label: "copy" },
                  { key: "Space", label: "select" },
                  { key: "Alt+1-9", label: "quick" },
                  { key: "Ctrl+T", label: "transform" },
                  { key: "Ctrl+P", label: "pin" },
                  { key: "Shift+Del", label: "clear" },
                  { key: "Esc", label: "dismiss" }
                ]

                Row {
                  id: hintRow
                  required property var modelData
                  spacing: Style.space(4)

                  Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: footerKey.implicitWidth + Style.space(8)
                    implicitHeight: Style.space(16)
                    radius: Style.space(3)
                    color: root.ghostFill

                    Text {
                      id: footerKey
                      anchors.centerIn: parent
                      text: hintRow.modelData.key
                      font.family: root.fontFam
                      font.pixelSize: Style.font.caption
                      color: Util.alpha(root.fg, 0.7)
                    }
                  }

                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: hintRow.modelData.label
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    color: Util.alpha(root.fg, 0.42)
                  }
                }
              }
            }

            Row {
              Layout.alignment: Qt.AlignVCenter
              spacing: Style.space(6)

              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(6)
                height: Style.space(6)
                radius: width / 2
                color: {
                  if (root.conn === "online") return root.isPaused ? root.urgent : root.accent
                  if (root.conn === "connecting") return Util.alpha(root.fg, 0.5)
                  return root.urgent
                }
              }

              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: {
                  if (root.conn === "connecting") return "connecting…"
                  if (root.conn !== "online") return "offline · run clipdeck doctor to diagnose"
                  var v = root.daemonVersion !== "" ? "v" + root.daemonVersion + " · " : ""
                  return v + root.totalItems + " clips stored" + (root.isPaused ? " · capture paused (Ctrl+I)" : "")
                }
                font.family: root.fontFam
                font.pixelSize: Style.font.caption
                color: Util.alpha(root.fg, 0.5)
              }
            }
          }
        }

        // ================= Toast ============================================
        Rectangle {
          id: toastPill
          z: 60
          visible: root.toast !== ""
          anchors.top: parent.top
          anchors.topMargin: header.height + Style.space(10)
          anchors.horizontalCenter: parent.horizontalCenter
          implicitWidth: toastRow.implicitWidth + Style.space(24)
          implicitHeight: Style.space(30)
          radius: height / 2
          color: root.toastOk ? root.accent : root.urgent

          Row {
            id: toastRow
            anchors.centerIn: parent
            spacing: Style.space(6)

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.toastOk ? "✓" : "!"
              font.family: root.fontFam
              font.pixelSize: Style.font.body
              font.bold: true
              color: DeckTheme.onFill(root.toastOk ? root.accent : root.urgent)
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: root.toast
              font.family: root.fontFam
              font.pixelSize: Style.font.body
              color: DeckTheme.onFill(root.toastOk ? root.accent : root.urgent)
              textFormat: Text.PlainText
            }
          }
        }

        // ================= Confirm dialog ====================================
        // Native shell dialog: identical visuals and key choreography to the
        // built-in clipboard menu (Esc cancels, ←/→ or Tab switches, Enter
        // activates the highlighted choice).
        ConfirmDialog {
          id: confirmDialog
          anchors.fill: parent
          z: 70
          opened: root.confirmOpen
          message: root.confirmMessage
          cancelText: "Cancel"
          confirmText: root.confirmKind === "clear" ? "Clear" : "Delete"
          background: root.bg
          foreground: root.fg
          scrim: Util.alpha(root.scrim, 0.9)
          selectedBackground: root.selFill
          selectedText: root.accent
          fontFamily: root.fontFam
          cornerRadius: root.radius
          onCanceled: root.confirmOpen = false
          onConfirmed: root.runConfirmed()
        }

        // ================= Transform picker ================================
        Rectangle {
          id: transformScrim
          z: 80
          anchors.fill: parent
          visible: root.transformOpen
          color: Util.alpha(root.scrim, 0.92)

          MouseArea {
            anchors.fill: parent
            onClicked: root.transformOpen = false
          }

          BorderSurface {
            id: transformCard
            anchors.centerIn: parent
            width: Math.min(Style.space(620), parent.width - Style.space(50))
            height: Math.min(Style.space(520), parent.height - Style.space(50))
            radius: root.radius
            color: root.bg
            borderSpec: root.borderSpec
            clip: true

            MouseArea { anchors.fill: parent }

            ColumnLayout {
              anchors.fill: parent
              anchors.margins: Style.space(16)
              spacing: Style.space(10)

              RowLayout {
                Layout.fillWidth: true
                spacing: Style.space(8)

                Text {
                  text: "Transform"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.title
                  font.bold: true
                  color: root.fg
                }

                Text {
                  Layout.fillWidth: true
                  text: root.activeItem !== null ? DeckTheme.clip(root.activeItem.preview || root.activeItem.content, 46) : ""
                  font.family: root.codeFam
                  font.pixelSize: Style.font.caption
                  color: Util.alpha(root.fg, 0.45)
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }

                Text {
                  text: "Enter copy · Shift+Enter paste · Esc back"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  color: Util.alpha(root.fg, 0.45)
                }
              }

              // Filter field (same rendered-field pattern as search).
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(32)
                radius: Math.min(root.radius, height / 2)
                color: root.ghostFill

                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  text: root.transformQuery !== "" ? root.transformQuery : "Filter transforms…"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.body
                  color: root.transformQuery !== "" ? root.fg : Util.alpha(root.fg, 0.4)
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                }
              }

              // Transform list, grouped by section header when the group
              // changes. Keyboard drives selection; hover follows along.
              ListView {
                id: transformList
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: root.filteredTransforms
                clip: true
                spacing: Style.space(2)
                boundsBehavior: Flickable.StopAtBounds

                delegate: Item {
                  id: trRow
                  required property var modelData
                  required property int index

                  readonly property bool newGroup: trRow.index === 0
                    || root.filteredTransforms[trRow.index - 1].group !== trRow.modelData.group

                  width: transformList.width
                  height: (trRow.newGroup ? Style.space(24) : 0) + Style.space(38)

                  Text {
                    id: groupHeader
                    visible: trRow.newGroup
                    anchors.top: parent.top
                    height: Style.space(24)
                    text: trRow.modelData.group.toUpperCase()
                    font.family: root.fontFam
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1.2
                    color: Util.alpha(root.fg, 0.45)
                  }

                  Rectangle {
                    id: trPill
                    anchors.top: groupHeader.visible ? groupHeader.bottom : parent.top
                    width: parent.width
                    height: Style.space(36)
                    radius: Math.min(root.radius, Style.space(8))
                    color: root.transformIndex === trRow.index
                      ? Util.alpha(root.accent, 0.16)
                      : (trHover.containsMouse ? root.ghostFill : "transparent")

                    Behavior on color { ColorAnimation { duration: 80 } }

                    RowLayout {
                      anchors.fill: parent
                      anchors.leftMargin: Style.space(10)
                      anchors.rightMargin: Style.space(10)
                      spacing: Style.space(10)

                      Text {
                        Layout.preferredWidth: Style.space(10)
                        text: root.transformIndex === trRow.index ? "›" : ""
                        font.family: root.fontFam
                        font.pixelSize: Style.font.title
                        color: root.accent
                      }

                      ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                          text: trRow.modelData.name
                          font.family: root.fontFam
                          font.pixelSize: Style.font.body
                          font.bold: root.transformIndex === trRow.index
                          color: root.fg
                          textFormat: Text.PlainText
                        }

                        Text {
                          Layout.fillWidth: true
                          text: trRow.modelData.desc
                          font.family: root.fontFam
                          font.pixelSize: Style.font.caption
                          color: Util.alpha(root.fg, 0.5)
                          elide: Text.ElideRight
                          textFormat: Text.PlainText
                        }
                      }

                      Text {
                        visible: root.transformIndex === trRow.index
                        text: "Enter"
                        font.family: root.fontFam
                        font.pixelSize: Style.font.caption
                        color: root.accent
                      }
                    }

                    MouseArea {
                      id: trHover
                      anchors.fill: parent
                      hoverEnabled: true
                      cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        root.transformIndex = trRow.index
                        root.applyTransform(false)
                      }
                      onPositionChanged: {
                        if (trHover.containsMouse && root.transformIndex !== trRow.index) {
                          root.transformIndex = trRow.index
                          transformPreviewTimer.restart()
                        }
                      }
                    }
                  }
                }
              }

              // Live preview of the highlighted transform.
              Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: Style.space(96)
                radius: Math.min(root.radius, Style.space(8))
                color: root.ghostFill
                clip: true

                Text {
                  id: previewLabel
                  anchors.top: parent.top
                  anchors.left: parent.left
                  anchors.margins: Style.space(10)
                  text: root.transformCurrent !== null ? "PREVIEW · " + root.transformCurrent.name.toUpperCase() : "PREVIEW"
                  font.family: root.fontFam
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1.0
                  color: Util.alpha(root.fg, 0.45)
                }

                Text {
                  anchors.top: previewLabel.bottom
                  anchors.topMargin: Style.space(6)
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.bottom: parent.bottom
                  anchors.leftMargin: Style.space(10)
                  anchors.rightMargin: Style.space(10)
                  anchors.bottomMargin: Style.space(8)
                  text: root.transformPreviewError !== ""
                    ? root.transformPreviewError
                    : (root.transformPreview !== "" ? root.transformPreview : "—")
                  font.family: root.codeFam
                  font.pixelSize: Style.font.caption
                  color: root.transformPreviewError !== "" ? root.urgent : Util.alpha(root.fg, 0.85)
                  wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                  elide: Text.ElideRight
                  maximumLineCount: 3
                  textFormat: Text.PlainText
                }
              }
            }
          }
        }
      }
    }
  }
}
