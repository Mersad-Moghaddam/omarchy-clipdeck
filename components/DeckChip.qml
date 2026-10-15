import QtQuick
import qs.Commons
import "../overlay/DeckTheme.js" as DeckTheme

// DeckChip: category filter pill for the ClipDeck rail. The active chip takes
// the accent fill (with a hue-preserving readable label); inactive chips stay
// quiet until hovered. Counts include the category's current item count so the
// rail doubles as a distribution summary.
Item {
  id: root

  property string label: ""
  property int count: -1
  property bool active: false

  signal clicked()

  readonly property bool hovered: mouse.containsMouse
  readonly property color accent: Color.accent
  readonly property color fg: Color.menu.text

  implicitWidth: content.implicitWidth + Style.space(18)
  implicitHeight: Math.max(Style.space(24), content.implicitHeight + Style.space(8))

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: height / 2
    color: root.active
      ? root.accent
      : (root.hovered ? Util.alpha(root.fg, 0.09) : Util.alpha(root.fg, 0.04))
    border.color: root.active ? "transparent" : Util.alpha(root.fg, root.hovered ? 0.24 : 0.12)
    border.width: root.active ? 0 : 1

    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(6)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.bold: root.active
      color: root.active ? DeckTheme.onFill(root.accent) : root.fg
    }

    Text {
      visible: root.count >= 0
      anchors.verticalCenter: parent.verticalCenter
      text: root.count
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: root.active
        ? Util.alpha(DeckTheme.onFill(root.accent), 0.7)
        : Util.alpha(root.fg, 0.45)
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
