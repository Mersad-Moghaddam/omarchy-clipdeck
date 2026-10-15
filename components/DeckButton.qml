import QtQuick
import qs.Commons
import "../overlay/DeckTheme.js" as DeckTheme

// DeckButton: the overlay's one button primitive — deliberately quiet.
//
// Minimal by contract: no borders, no shadows, no gradients. The shape is a
// flat fill that appears on hover/press and disappears otherwise, in the
// spirit of the shell's own panels. Variants:
//   primary — the single accent-filled focal action
//   ghost   — the default; fill only while hovered, pressed, or active
//   danger  — urgent-colored label; fill only while hovered, pressed, or
//             when it is the active choice (never a standing red block)
// The optional `hint` is rendered as plain muted keycap text ("Enter",
// "Ctrl+T") — documentation without another pill.
Item {
  id: root

  property string label: ""
  property string glyph: ""
  property string hint: ""
  property string variant: "ghost"
  property bool compact: false
  property bool active: false

  signal clicked()

  readonly property bool hovered: mouse.containsMouse && root.enabled
  readonly property bool pressed: mouse.pressed && root.enabled
  readonly property bool primary: root.variant === "primary"
  readonly property bool danger: root.variant === "danger"

  readonly property color accent: Color.accent
  readonly property color urgent: Color.urgent
  readonly property color fg: Color.menu.text

  readonly property color fill: {
    if (!root.enabled) return "transparent"
    if (root.primary) {
      if (root.pressed) return DeckTheme.mix(root.accent, Color.menu.background, 0.25)
      if (root.hovered) return DeckTheme.mix(root.accent, Color.menu.text, 0.12)
      return root.accent
    }
    if (root.danger) {
      if (root.pressed) return Util.alpha(root.urgent, 0.26)
      if (root.hovered) return Util.alpha(root.urgent, 0.16)
      return "transparent"
    }
    if (root.active) return Util.alpha(root.accent, 0.14)
    if (root.pressed) return Style.pressedFill
    if (root.hovered) return Style.hoverFill
    return "transparent"
  }

  readonly property color labelColor: {
    if (!root.enabled) return Util.alpha(root.fg, 0.35)
    if (root.primary) return DeckTheme.onFill(root.accent)
    if (root.danger) return root.urgent
    if (root.active) return root.accent
    return root.fg
  }

  readonly property color hintColor: root.primary
    ? Util.alpha(DeckTheme.onFill(root.accent), 0.6)
    : Util.alpha(root.danger ? root.urgent : root.fg, 0.42)

  readonly property int hPadding: root.compact ? Style.space(7) : Style.space(10)
  readonly property int vPadding: root.compact ? Style.space(3) : Style.space(4)

  implicitWidth: layout.implicitWidth + root.hPadding * 2
  implicitHeight: Math.max(root.compact ? Style.space(22) : Style.space(27), layout.implicitHeight + root.vPadding * 2)

  opacity: root.enabled ? 1.0 : 0.55
  Behavior on opacity { NumberAnimation { duration: 90 } }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Math.min(Style.cornerRadius, height / 2)
    color: root.fill
    Behavior on color { ColorAnimation { duration: 90; easing.type: Easing.OutCubic } }
  }

  Row {
    id: layout
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      id: glyphText
      visible: root.glyph !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.glyph
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.body
      color: root.labelColor
      Behavior on color { ColorAnimation { duration: 90 } }
    }

    Text {
      id: labelText
      visible: root.label !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      font.family: Style.font.menuFamily
      font.pixelSize: root.compact ? Style.font.caption : Style.font.body
      font.bold: root.primary
      color: root.labelColor
      elide: Text.ElideRight
      Behavior on color { ColorAnimation { duration: 90 } }
    }

    // Inline shortcut hint: plain muted mono text, no chip, no border.
    Text {
      id: hintText
      visible: root.hint !== ""
      anchors.verticalCenter: parent.verticalCenter
      text: root.hint
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: root.hintColor
      Behavior on color { ColorAnimation { duration: 90 } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    enabled: root.enabled
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
