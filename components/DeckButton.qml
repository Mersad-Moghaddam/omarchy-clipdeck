import QtQuick
import qs.Commons
import "../overlay/DeckTheme.js" as DeckTheme

// DeckButton: one themed button primitive for the whole overlay.
//
// Variants map onto shell state tokens instead of inventing fills:
//   primary — accent fill, hue-preserving readable label
//   ghost   — transparent, token hover/pressed fills (the default action look)
//   danger  — urgent-tinted fill for destructive actions
//
// The optional `hint` renders as an inline keycap ("⏎", "⌃T") so action bars
// double as discoverable keyboard documentation.
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
      if (root.pressed) return Util.alpha(root.urgent, 0.3)
      if (root.hovered) return Util.alpha(root.urgent, 0.22)
      return Util.alpha(root.urgent, 0.14)
    }
    if (root.active) return Util.alpha(root.accent, 0.18)
    if (root.pressed) return Style.pressedFill
    if (root.hovered) return Style.hoverFill
    return "transparent"
  }

  readonly property color borderColor: {
    if (!root.enabled) return "transparent"
    if (root.primary) return "transparent"
    if (root.danger) return Util.alpha(root.urgent, root.hovered ? 0.75 : 0.45)
    if (root.active) return Util.alpha(root.accent, 0.8)
    return root.hovered ? Style.hoverBorderColor : Style.normalBorderColor
  }

  readonly property color labelColor: {
    if (!root.enabled) return Util.alpha(root.fg, 0.35)
    if (root.primary) return DeckTheme.onFill(root.accent)
    if (root.danger) return root.urgent
    if (root.active) return root.accent
    return root.fg
  }

  readonly property color hintColor: root.primary
    ? Util.alpha(DeckTheme.onFill(root.accent), 0.65)
    : Util.alpha(root.danger ? root.urgent : root.fg, 0.55)

  readonly property int hPadding: root.compact ? Style.space(8) : Style.space(12)
  readonly property int vPadding: root.compact ? Style.space(4) : Style.space(6)

  implicitWidth: layout.implicitWidth + root.hPadding * 2
  implicitHeight: Math.max(Style.spacing.controlHeight, layout.implicitHeight + root.vPadding * 2)

  opacity: root.enabled ? 1.0 : 0.55
  Behavior on opacity { NumberAnimation { duration: 90 } }

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: Math.min(Style.cornerRadius, height / 2)
    color: root.fill
    border.color: root.borderColor
    border.width: root.borderColor.a > 0 ? 1 : 0

    Behavior on color { ColorAnimation { duration: 90; easing.type: Easing.OutCubic } }
    Behavior on border.color { ColorAnimation { duration: 90; easing.type: Easing.OutCubic } }
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
      font.pixelSize: Style.font.body
      font.bold: root.primary
      color: root.labelColor
      elide: Text.ElideRight
      Behavior on color { ColorAnimation { duration: 90 } }
    }

    // Inline keycap. Deliberately quiet: it documents the shortcut without
    // competing with the action label.
    Rectangle {
      visible: root.hint !== ""
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: hintText.implicitWidth + Style.space(7)
      implicitHeight: hintText.implicitHeight + Style.space(2)
      radius: Math.min(Style.cornerRadius, height / 2)
      color: Util.alpha(root.hintColor, 0.14)
      border.color: Util.alpha(root.hintColor, 0.35)
      border.width: 1

      Text {
        id: hintText
        anchors.centerIn: parent
        text: root.hint
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        color: root.hintColor
      }
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
