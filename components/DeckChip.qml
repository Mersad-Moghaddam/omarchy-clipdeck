import QtQuick
import qs.Commons

// DeckChip: category filter chip for the ClipDeck rail — flat and quiet.
//
// Inactive chips are bare text (no fill, no border) and only pick up a
// faint fill on hover. The active chip uses the menu surface's own
// selected tokens (selectedBackground / selectedText), exactly like the
// built-in clipboard list, so the rail reads as part of the shell rather
// than a custom widget. Counts stay muted so the label is what the eye
// lands on.
Item {
  id: root

  property string label: ""
  property int count: -1
  property bool active: false

  signal clicked()

  readonly property bool hovered: mouse.containsMouse
  readonly property color fg: Color.menu.text
  readonly property color selectedFill: Color.menu.selectedBackground
  readonly property color selectedText: Color.menu.selectedText

  implicitWidth: content.implicitWidth + Style.space(16)
  implicitHeight: Math.max(Style.space(22), content.implicitHeight + Style.space(6))

  Rectangle {
    id: bg
    anchors.fill: parent
    radius: height / 2
    color: root.active
      ? root.selectedFill
      : (root.hovered ? Util.alpha(root.fg, 0.07) : "transparent")
    Behavior on color { ColorAnimation { duration: 100; easing.type: Easing.OutCubic } }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(5)

    Text {
      anchors.verticalCenter: parent.verticalCenter
      text: root.label
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.caption
      font.bold: root.active
      color: root.active ? root.selectedText : Util.alpha(root.fg, root.hovered ? 1.0 : 0.78)
      Behavior on color { ColorAnimation { duration: 100 } }
    }

    Text {
      visible: root.count >= 0
      anchors.verticalCenter: parent.verticalCenter
      text: root.count
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: root.active ? Util.alpha(root.selectedText, 0.65) : Util.alpha(root.fg, 0.38)
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
