import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "CalendarModel.js" as CalendarModel

// Detail panel.  It consumes already-calculated JSON from BarWidget.qml and
// therefore never starts astronomy work itself.  A missing location remains a
// visible, honest failure state instead of displaying guessed Panchāṅga data.
Panel {
  id: root
  moduleName: "local.hindu-calendar"
  ipcTarget: "local.hindu-calendar"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property var panchangData: ({ status: "loading" })
  property string viewMode: "panchang"
  property date today: new Date()
  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()
  property date selectedDate: today
  readonly property date viewDate: new Date(viewYear, viewMonth, 1)
  readonly property var monthCells: CalendarModel.monthCells(viewYear, viewMonth)
  readonly property var barIdentity: hostWidget || root
  readonly property color contentForeground: bar ? bar.foreground : Color.foreground
  readonly property string contentFontFamily: bar ? bar.fontFamily : Style.font.family

  function open() {
    root.controller.show()
    Qt.callLater(function() { if (root.opened) setCenterHoverRevealSuppressed(true) })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() { root.opened ? root.close() : root.open() }
  function refresh() { if (hostWidget && hostWidget.refreshPanchang) hostWidget.refreshPanchang() }
  function switchPanel(direction) {
    return root.bar && root.bar.switchPanelFrom ? root.bar.switchPanelFrom(root.barIdentity, direction) : false
  }
  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar) root.bar.centerHoverRevealSuppressed = value
  }
  function timeAt(value) { return value ? String(value).slice(11, 16) : "—" }
  function interval(values) {
    return values && values.length === 2 ? timeAt(values[0]) + " – " + timeAt(values[1]) : "—"
  }
  function panchangValue(label) {
    if (root.panchangData.status !== "ok" || !root.panchangData.panchang) return "—"
    for (var index = 0; index < root.panchangData.panchang.length; index++) {
      var item = root.panchangData.panchang[index]
      if (item.label === label) return item.value || "—"
    }
    return "—"
  }
  function tithiWithoutPaksha() {
    var tithi = panchangValue("Tithi")
    var paksha = panchangValue("Pakṣa")
    var prefix = paksha + " "
    return tithi.indexOf(prefix) === 0 ? tithi.slice(prefix.length) : tithi
  }
  function showView(view) { root.viewMode = view }
  function moveMonth(delta) {
    var next = CalendarModel.stepMonth(root.viewYear, root.viewMonth, delta)
    root.viewYear = next.year
    root.viewMonth = next.month
  }
  function goToToday() {
    root.viewYear = root.today.getFullYear()
    root.viewMonth = root.today.getMonth()
    root.selectedDate = root.today
  }
  function selectDay(cell) {
    root.selectedDate = new Date(cell.year, cell.month, cell.day)
    if (!cell.inMonth) {
      root.viewYear = cell.year
      root.viewMonth = cell.month
    }
  }

  SystemClock {
    id: panelClock
    precision: SystemClock.Minutes
    onDateChanged: {
      var wasToday = CalendarModel.sameDay(root.selectedDate, root.today)
      var wasViewingToday = root.viewYear === root.today.getFullYear() && root.viewMonth === root.today.getMonth()
      root.today = date
      if (wasToday) root.selectedDate = date
      if (wasViewingToday) {
        root.viewYear = date.getFullYear()
        root.viewMonth = date.getMonth()
      }
    }
  }

  component SectionLabel: Text {
    property string sectionText: ""
    text: sectionText.toUpperCase()
    color: Qt.darker(root.contentForeground, 1.45)
    font.family: root.contentFontFamily
    font.pixelSize: Style.font.bodySmall
    font.letterSpacing: 1.1
  }

  component DetailRow: Item {
    property var entry: ({})
    width: parent ? parent.width : 1
    implicitHeight: valueText.implicitHeight + Style.space(6)
    Text {
      id: labelText
      width: Style.space(118)
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      text: entry.label || ""
      color: Qt.darker(root.contentForeground, 1.25)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
    }
    Text {
      id: valueText
      anchors.left: labelText.right
      anchors.right: endText.left
      anchors.rightMargin: Style.space(10)
      anchors.verticalCenter: parent.verticalCenter
      text: (entry.devanagari ? entry.devanagari + " · " : "") + (entry.value || "—")
      color: root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }
    Text {
      id: endText
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      text: entry.ends ? "to " + root.timeAt(entry.ends) : ""
      color: Qt.darker(root.contentForeground, 1.55)
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
    }
  }

  component ViewButton: Item {
    property string label: ""
    property string mode: ""
    readonly property bool active: root.viewMode === mode
    implicitWidth: Style.space(116)
    implicitHeight: Style.space(28)
    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius
      color: parent.active ? Color.accent : "transparent"
      border.width: Style.spacing.hairline
      border.color: parent.active ? Color.accent : Qt.rgba(root.contentForeground.r, root.contentForeground.g, root.contentForeground.b, 0.22)
    }
    Text {
      anchors.centerIn: parent
      text: parent.label
      color: parent.active ? Color.background : root.contentForeground
      font.family: root.contentFontFamily
      font.pixelSize: Style.font.bodySmall
      font.bold: parent.active
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: root.showView(parent.mode)
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(530))
    contentHeight: panel.fittedContentHeight(content.implicitHeight, Style.space(720))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onMoveRequested: function(dx, dy) {
        if (root.viewMode !== "calendar") return
        if (dx !== 0) root.moveMonth(dx)
        else if (dy !== 0) root.moveMonth(dy)
      }
      onTextKey: function(text) {
        if (text === "r" || text === "R") root.refresh()
        else if (text === "c" || text === "C") root.showView("calendar")
        else if (text === "p" || text === "P") root.showView("panchang")
        else if (text === "[") root.moveMonth(-1)
        else if (text === "]") root.moveMonth(1)
        else if (text === "t" || text === "T") root.goToToday()
      }

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: content
          width: parent.width
          spacing: Style.space(10)

          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.panchangData.status === "ok" ? root.panchangData.header.gregorian : "Hindu Calendar"
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.panchangData.status === "ok"
            text: root.panchangData.status === "ok"
              ? root.panchangData.header.time + " · " + root.panchangData.header.timezone + " · " + root.panchangData.header.location
              : ""
            color: Qt.darker(root.contentForeground, 1.4)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok"
            text: root.panchangData.status === "ok"
              ? root.panchangValue("Māsa") + " · " + root.panchangValue("Pakṣa") + " Pakṣa · " + root.tithiWithoutPaksha()
              : ""
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.subtitle
            font.bold: true
          }
          Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok"
            text: root.panchangData.status === "ok"
              ? "Vikrama Saṁvat " + root.panchangData.header.vikram_samvat.year + " · " + root.panchangData.header.vikram_samvat.convention
              : ""
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Style.space(6)
            ViewButton { label: "Pañcāṅga"; mode: "panchang" }
            ViewButton { label: "Calendar"; mode: "calendar" }
          }

          Rectangle { width: parent.width; height: Style.spacing.hairline; color: root.contentForeground; opacity: 0.14 }

          Text {
            visible: root.viewMode === "panchang" && root.panchangData.status !== "ok"
            width: parent.width
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: root.panchangData.status === "loading"
              ? "Calculating the local Pañcāṅga…"
              : (root.panchangData.error || "Pañcāṅga data is unavailable.") + "\n\nSet latitude and longitude in ~/.config/omarchy/hindu-calendar.json, then press R to retry."
            color: root.contentForeground
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.body
          }

          Column {
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok"
            width: parent.width
            spacing: Style.space(4)
            SectionLabel { sectionText: "Pañcāṅga · Lahiri / Chitrapakṣa" }
            Repeater {
              model: root.panchangData.status === "ok" ? root.panchangData.panchang : []
              delegate: DetailRow { entry: modelData }
            }
          }

          Column {
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok"
            width: parent.width
            spacing: Style.space(4)
            SectionLabel { sectionText: "Solar & lunar" }
            DetailRow { entry: ({ label: "Sūryodaya", value: root.panchangData.status === "ok" ? root.timeAt(root.panchangData.solar_lunar.sunrise) : "" }) }
            DetailRow { entry: ({ label: "Sūryāsta", value: root.panchangData.status === "ok" ? root.timeAt(root.panchangData.solar_lunar.sunset) : "" }) }
            DetailRow { entry: ({ label: "Candrodaya", value: root.panchangData.status === "ok" ? root.timeAt(root.panchangData.solar_lunar.moonrise) : "" }) }
            DetailRow { entry: ({ label: "Candrāsta", value: root.panchangData.status === "ok" ? root.timeAt(root.panchangData.solar_lunar.moonset) : "" }) }
            DetailRow { entry: ({ label: "Moon phase", value: root.panchangData.status === "ok" ? root.panchangData.solar_lunar.illumination_approx + "% illuminated" : "" }) }
            DetailRow { entry: ({ label: "Saṅkrānti", value: root.panchangData.status === "ok" ? root.panchangData.solar_lunar.sankranti.name + " · " + root.timeAt(root.panchangData.solar_lunar.sankranti.at) : "" }) }
          }

          Column {
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok"
            width: parent.width
            spacing: Style.space(4)
            SectionLabel { sectionText: "Daily windows" }
            DetailRow { entry: ({ label: "Rāhu Kāla", value: root.panchangData.status === "ok" ? root.interval(root.panchangData.muhurta.rahu_kalam) : "" }) }
            DetailRow { entry: ({ label: "Yamaganda", value: root.panchangData.status === "ok" ? root.interval(root.panchangData.muhurta.yamaganda) : "" }) }
            DetailRow { entry: ({ label: "Gulika Kāla", value: root.panchangData.status === "ok" ? root.interval(root.panchangData.muhurta.gulika_kalam) : "" }) }
            DetailRow { entry: ({ label: "Abhijit Muhūrta", value: root.panchangData.status === "ok" ? root.interval(root.panchangData.muhurta.abhijit_muhurta) : "" }) }
            DetailRow { entry: ({ label: "Brahma Muhūrta", value: root.panchangData.status === "ok" ? root.interval(root.panchangData.muhurta.brahma_muhurta) : "" }) }
          }

          Column {
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok" && root.panchangData.traditional_time !== null
            width: parent.width
            spacing: Style.space(4)
            SectionLabel { sectionText: "Traditional time" }
            DetailRow { entry: ({ label: "Prahara", value: root.panchangData.status === "ok" ? root.panchangData.traditional_time.prahara + " of 8" : "" }) }
            DetailRow { entry: ({ label: "Muhūrta", value: root.panchangData.status === "ok" ? root.panchangData.traditional_time.muhurta + " of 30" : "" }) }
            DetailRow { entry: ({ label: "Ghaṭī · Kalā", value: root.panchangData.status === "ok" ? root.panchangData.traditional_time.ghati + " · " + root.panchangData.traditional_time.kala : "" }) }
          }

          Text {
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok" && root.panchangData.observances && root.panchangData.observances.length > 0
            width: parent.width
            wrapMode: Text.WordWrap
            text: root.panchangData.status === "ok" ? root.panchangData.observances.join("\n") : ""
            color: Color.accent
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Text {
            visible: root.viewMode === "panchang" && root.panchangData.status === "ok"
            width: parent.width
            wrapMode: Text.WordWrap
            text: "Calculated locally with Swiss Ephemeris · " + (root.panchangData.status === "ok" ? root.panchangData.methodology.lunar_month_convention + " lunar month · " + root.panchangData.methodology.sunrise_mode : "") + " · Press R to refresh."
            color: Qt.darker(root.contentForeground, 1.6)
            font.family: root.contentFontFamily
            font.pixelSize: Style.font.bodySmall
          }

          Column {
            visible: root.viewMode === "calendar"
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              height: monthTitle.implicitHeight + Style.space(10)
              PanelActionButton {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅁"
                tooltipText: "Previous month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(-1)
              }
              Text {
                id: monthTitle
                anchors.centerIn: parent
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                color: root.contentForeground
                font.family: root.contentFontFamily
                font.pixelSize: Style.font.title
                font.bold: true
              }
              PanelActionButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰅂"
                tooltipText: "Next month"
                foreground: root.contentForeground
                fontFamily: root.contentFontFamily
                onClicked: root.moveMonth(1)
              }
            }

            Row {
              id: weekdayHeader
              width: parent.width
              Repeater {
                model: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
                delegate: Text {
                  required property string modelData
                  width: weekdayHeader.width / 7
                  horizontalAlignment: Text.AlignHCenter
                  text: modelData
                  color: Qt.darker(root.contentForeground, 1.5)
                  font.family: root.contentFontFamily
                  font.pixelSize: Style.font.caption
                  font.letterSpacing: 0.7
                }
              }
            }

            Grid {
              id: calendarGrid
              width: parent.width
              columns: 7
              rowSpacing: Style.space(2)
              columnSpacing: 0
              Repeater {
                model: root.monthCells
                delegate: Item {
                  required property var modelData
                  width: calendarGrid.width / 7
                  height: Style.space(34)
                  readonly property bool selected: CalendarModel.sameDay(root.selectedDate, modelData.date)
                  readonly property bool isToday: CalendarModel.sameDay(root.today, modelData.date)
                  Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - Style.space(4), Style.space(30))
                    height: width
                    radius: width / 2
                    color: parent.selected ? Color.accent : (parent.isToday ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18) : "transparent")
                    border.width: parent.isToday && !parent.selected ? Style.spacing.hairline : 0
                    border.color: Color.accent
                  }
                  Text {
                    anchors.centerIn: parent
                    text: modelData.day
                    color: parent.selected ? Color.background : (modelData.inMonth ? root.contentForeground : Qt.darker(root.contentForeground, 2.0))
                    opacity: modelData.inMonth ? 1 : 0.45
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.body
                    font.bold: parent.selected || parent.isToday
                  }
                  MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectDay(modelData)
                  }
                }
              }
            }

            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "Selected: " + Qt.formatDate(root.selectedDate, "dddd, d MMMM yyyy")
              color: root.contentForeground
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.body
            }
            Text {
              width: parent.width
              horizontalAlignment: Text.AlignHCenter
              text: "Use ‹ ›, arrow keys, or [ ] to change month · T returns to today"
              color: Qt.darker(root.contentForeground, 1.6)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }
      }
    }
  }
}
