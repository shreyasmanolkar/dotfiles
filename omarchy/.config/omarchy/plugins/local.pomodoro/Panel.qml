import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import qs.Commons
import qs.Ui
import "TimerModel.js" as TimerModel

// A deliberately short, keyboard-friendly control panel. The host widget
// owns timer state; this panel is only the native Omarchy surface for it.
Panel {
  id: root
  moduleName: "local.pomodoro"
  ipcTarget: "local.pomodoro"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var timer: hostWidget
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property color timerColor: timer ? timer.stateColor : Color.accent

  function open() {
    root.controller.show()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() { root.opened ? root.close() : root.open() }
  function switchPanel(direction) {
    return root.bar && root.bar.switchPanelFrom ? root.bar.switchPanelFrom(root.barIdentity, direction) : false
  }
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar) root.bar.centerHoverRevealSuppressed = value
  }

  component MetricCard: BorderSurface {
    property string label: ""
    property string value: ""
    property color foreground: Color.foreground
    property string fontFamily: Style.font.family
    implicitHeight: metricColumn.implicitHeight + Style.space(14)
    radius: Style.cornerRadius
    color: Qt.rgba(foreground.r, foreground.g, foreground.b, 0.045)
    borderSpec: Border.controlSpec("normal", foreground, Color.accent)

    Column {
      id: metricColumn
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(9)
      anchors.rightMargin: Style.space(9)
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: parent.parent.label.toUpperCase()
        color: Qt.darker(parent.parent.foreground, 1.45)
        font.family: parent.parent.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        elide: Text.ElideRight
      }
      Text {
        width: parent.width
        text: parent.parent.value
        color: parent.parent.foreground
        font.family: parent.parent.fontFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        elide: Text.ElideRight
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: if (root.timer) root.timer.primaryAction()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (!root.timer) return
        if (text === "r" || text === "R") root.timer.resetTimer()
        else if (text >= "1" && text <= "6") root.timer.selectPresetAt(Number(text) - 1)
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        Controls.ScrollBar.vertical: Controls.ScrollBar { policy: Controls.ScrollBar.AsNeeded }

        Column {
          id: content
          width: flick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Focus timer"
            meta: root.timer ? root.timer.statusLabel + " · " + root.timer.selectedPreset.label : "READY"
            detail: root.timer ? root.timer.selectedPreset.shortLabel : "25 min"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: root.timer ? root.timer.statusGlyph : "◷"
                color: root.timerColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Item {
            width: parent.width
            implicitHeight: countdown.implicitHeight + endTime.implicitHeight + elapsed.implicitHeight + Style.space(12)

            Text {
              id: countdown
              anchors.top: parent.top
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.timer ? root.timer.remainingText : "25:00"
              color: root.timerColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.display * 1.45
              font.bold: true
            }

            Text {
              id: endTime
              anchors.top: countdown.bottom
              anchors.topMargin: Style.space(2)
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.timer ? root.timer.endTimeText() : ""
              visible: text !== ""
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }

            Text {
              id: elapsed
              anchors.top: endTime.visible ? endTime.bottom : countdown.bottom
              anchors.topMargin: Style.space(2)
              anchors.horizontalCenter: parent.horizontalCenter
              text: root.timer ? TimerModel.formatDuration(root.timer.sessionElapsedSeconds) + " elapsed" : ""
              visible: root.timer && root.timer.status !== "ready"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            width: parent.width
            height: Math.max(2, Style.spacing.hairline * 2)
            radius: height / 2
            color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.13)

            Rectangle {
              width: parent.width * (root.timer ? root.timer.progress : 0)
              height: parent.height
              radius: parent.radius
              color: root.timerColor
              Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(8)

            Button {
              width: (parent.width - parent.spacing) / 2
              text: root.timer ? root.timer.primaryActionLabel : "Start"
              iconText: root.timer ? root.timer.primaryActionIcon : "▶"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              selected: true
              onClicked: if (root.timer) root.timer.primaryAction()
            }

            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Reset"
              iconText: "↺"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: if (root.timer) root.timer.resetTimer()
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "FOCUS DASHBOARD"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: metricGrid
              width: parent.width
              columns: 2
              rowSpacing: Style.space(6)
              columnSpacing: Style.space(6)

              MetricCard {
                width: (metricGrid.width - metricGrid.columnSpacing) / metricGrid.columns
                label: "Today"
                value: root.timer ? TimerModel.formatDuration(root.timer.dashboard.todayFocusSeconds) : "0m"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              MetricCard {
                width: (metricGrid.width - metricGrid.columnSpacing) / metricGrid.columns
                label: "Today sessions"
                value: root.timer ? String(root.timer.dashboard.todaySessions) : "0"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              MetricCard {
                width: (metricGrid.width - metricGrid.columnSpacing) / metricGrid.columns
                label: "Streak"
                value: root.timer ? root.timer.dashboard.streakDays + (root.timer.dashboard.streakDays === 1 ? " day" : " days") : "0 days"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              MetricCard {
                width: (metricGrid.width - metricGrid.columnSpacing) / metricGrid.columns
                label: "Average"
                value: root.timer ? TimerModel.formatDuration(root.timer.dashboard.averageFocusSeconds) : "0m"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              MetricCard {
                width: (metricGrid.width - metricGrid.columnSpacing) / metricGrid.columns
                label: "All focus"
                value: root.timer ? TimerModel.formatDuration(root.timer.dashboard.totalFocusSeconds) : "0m"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
              MetricCard {
                width: (metricGrid.width - metricGrid.columnSpacing) / metricGrid.columns
                label: "Completed"
                value: root.timer ? String(root.timer.dashboard.totalSessions) + " sessions" : "0 sessions"
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
            }

            Item {
              width: parent.width
              height: Style.space(74)

              Row {
                id: weeklyBars
                anchors.fill: parent
                spacing: Style.space(4)

                Repeater {
                  model: root.timer ? root.timer.dashboard.lastSeven : []

                  delegate: Column {
                    required property var modelData
                    width: (weeklyBars.width - weeklyBars.spacing * 6) / 7
                    height: weeklyBars.height
                    spacing: Style.space(2)

                    Text {
                      width: parent.width
                      text: TimerModel.formatDuration(modelData.focusSeconds)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignHCenter
                      elide: Text.ElideRight
                    }

                    Item {
                      width: parent.width
                      height: Style.space(42)

                      Rectangle {
                        width: Math.max(3, Math.min(parent.width, Style.space(10)))
                        height: parent.height
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.12)
                      }
                      Rectangle {
                        width: Math.max(3, Math.min(parent.width, Style.space(10)))
                        height: root.timer && root.timer.dashboard.weeklyMaximum > 0
                          ? Math.max(3, parent.height * modelData.focusSeconds / root.timer.dashboard.weeklyMaximum) : 3
                        radius: width / 2
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        color: root.timerColor
                        Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                      }
                    }

                    Text {
                      width: parent.width
                      text: modelData.key.slice(8)
                      color: root.dim
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      horizontalAlignment: Text.AlignHCenter
                    }
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "DURATION"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Grid {
              id: presetGrid
              width: parent.width
              columns: 2
              rowSpacing: Style.space(6)
              columnSpacing: Style.space(6)

              Repeater {
                model: root.timer ? root.timer.presets : []

                delegate: Button {
                  required property var modelData
                  width: (presetGrid.width - presetGrid.columnSpacing) / presetGrid.columns
                  text: modelData.label + " · " + modelData.shortLabel
                  tooltipText: modelData.description
                  foreground: root.foreground
                  accent: Color.accent
                  fontFamily: root.fontFamily
                  fontSize: Style.font.bodySmall
                  horizontalPadding: Style.space(7)
                  verticalPadding: Style.space(5)
                  bordered: true
                  selected: root.timer && root.timer.selectedPresetId === modelData.id
                  onClicked: if (root.timer) root.timer.selectPreset(modelData.id)
                }
              }
            }
          }

          Text {
            width: parent.width
            text: "1 Murut (Muhūrta) = 48 minutes · choosing a duration resets the timer."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
          }

          Text {
            width: parent.width
            text: "Space starts or pauses · R resets · 1–6 chooses a duration"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
