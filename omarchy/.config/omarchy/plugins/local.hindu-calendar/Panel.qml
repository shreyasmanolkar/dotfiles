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

  // A deliberately schematic, data-driven cycle view.  It repaints only when
  // the cached ephemeris values or theme colours change; the minute clock does
  // not trigger any canvas animation or astronomy work.
  component OrbitDiagram: Canvas {
    property real earthLongitude: 0
    property real phaseDegrees: 0
    property real moonSidereal: 0
    property real sunSidereal: 0
    property color foreground: root.contentForeground
    property color accent: Color.accent

    onEarthLongitudeChanged: requestPaint()
    onPhaseDegreesChanged: requestPaint()
    onMoonSiderealChanged: requestPaint()
    onSunSiderealChanged: requestPaint()
    onForegroundChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var cx = width * 0.50
      var cy = height * 0.49
      var rx = Math.max(90, width * 0.46)
      var ry = Math.max(58, height * 0.40)
      var fg = String(foreground)
      var hi = String(accent)
      var tau = Math.PI * 2

      function point(angle, radialScale) {
        var a = angle * Math.PI / 180 - Math.PI / 2
        return { x: cx + rx * radialScale * Math.cos(a), y: cy + ry * radialScale * Math.sin(a) }
      }
      function ellipse(stroke, alpha, lineWidth, radialScale) {
        var scale = radialScale || 1
        ctx.save()
        ctx.translate(cx, cy)
        ctx.scale(rx * scale, ry * scale)
        ctx.beginPath()
        ctx.arc(0, 0, 1, 0, tau)
        ctx.restore()
        ctx.globalAlpha = alpha
        ctx.strokeStyle = stroke
        ctx.lineWidth = lineWidth
        ctx.stroke()
        ctx.globalAlpha = 1
      }
      function circle(x, y, radius, fill, stroke) {
        ctx.beginPath()
        ctx.arc(x, y, radius, 0, tau)
        ctx.fillStyle = fill
        ctx.fill()
        if (stroke) {
          ctx.strokeStyle = stroke
          ctx.lineWidth = 1
          ctx.stroke()
        }
      }
      function ringLabel(label, angle, radialScale, fontSize, fill, alpha, bold) {
        var a = angle * Math.PI / 180 - Math.PI / 2
        var labelPoint = point(angle, radialScale)
        var tangent = Math.atan2(ry * radialScale * Math.cos(a), -rx * radialScale * Math.sin(a))
        if (tangent > Math.PI / 2 || tangent < -Math.PI / 2) tangent += Math.PI
        ctx.save()
        ctx.translate(labelPoint.x, labelPoint.y)
        ctx.rotate(tangent)
        ctx.textAlign = "center"
        ctx.textBaseline = "middle"
        ctx.font = (bold ? "700 " : "500 ") + fontSize + "px sans-serif"
        ctx.fillStyle = fill
        ctx.globalAlpha = alpha
        ctx.fillText(label, 0, 0)
        ctx.restore()
      }

      // Three concentric layers: the outer 27-part nakṣatra band, the inner
      // twelve-month band, and a compact central annual Pṛthvī orbit.
      ellipse(fg, 0.30, 1, 1.0)
      ellipse(fg, 0.20, 1, 0.79)
      ellipse(fg, 0.20, 1, 0.57)
      ellipse(fg, 0.18, 1, 0.43)

      var nakshatraLabels = [
        "Aśvinī", "Bharaṇī", "Kṛttikā", "Rohiṇī", "Mṛgaś.", "Ārdrā", "Punarv.",
        "Puṣya", "Āśleṣā", "Maghā", "P. Phalg.", "U. Phalg.", "Hastā", "Citrā",
        "Svātī", "Viśākhā", "Anurā.", "Jyeṣṭhā", "Mūlā", "P. Āṣā.", "U. Āṣā.",
        "Śravaṇā", "Dhaniṣ.", "Śatabhi.", "P. Bhādra", "U. Bhādra", "Revatī"
      ]
      var activeNakshatra = Math.floor((((moonSidereal % 360) + 360) % 360) / (360 / 27))
      for (var index = 0; index < 27; index++) {
        var angle = index * 360 / 27
        var inner = point(angle, index === activeNakshatra ? 0.76 : 0.79)
        var outer = point(angle, 1.0)
        ctx.beginPath()
        ctx.moveTo(inner.x, inner.y)
        ctx.lineTo(outer.x, outer.y)
        ctx.strokeStyle = index === activeNakshatra ? hi : fg
        ctx.globalAlpha = index === activeNakshatra ? 1 : 0.24
        ctx.lineWidth = index === activeNakshatra ? 2.5 : 1
        ctx.stroke()
        ringLabel(
          nakshatraLabels[index], angle + 360 / 54, 0.89,
          index === activeNakshatra ? 6.9 : 6.2,
          index === activeNakshatra ? hi : fg,
          index === activeNakshatra ? 1 : 0.63,
          index === activeNakshatra
        )
      }
      ctx.globalAlpha = 1
      for (var solarIndex = 0; solarIndex < 12; solarIndex++) {
        var solarAngle = solarIndex * 30
        var solarInner = point(solarAngle, 0.57)
        var solarOuter = point(solarAngle, 0.79)
        ctx.beginPath()
        ctx.moveTo(solarInner.x, solarInner.y)
        ctx.lineTo(solarOuter.x, solarOuter.y)
        ctx.strokeStyle = fg
        ctx.globalAlpha = 0.42
        ctx.lineWidth = 1
        ctx.stroke()
      }
      ctx.globalAlpha = 1

      // Solar months share the twelve 30° Lahiri rāśi sectors.
      var solarMonths = [
        "Meṣa", "Vṛṣabha", "Mithuna", "Karka", "Siṁha", "Kanyā",
        "Tulā", "Vṛścika", "Dhanuṣ", "Makara", "Kumbha", "Mīna"
      ]
      var activeSolarMonth = Math.floor((((sunSidereal % 360) + 360) % 360) / 30)
      for (var monthIndex = 0; monthIndex < solarMonths.length; monthIndex++) {
        var isActiveMonth = monthIndex === activeSolarMonth
        ringLabel(
          solarMonths[monthIndex], monthIndex * 30 + 15, 0.68,
          isActiveMonth ? 8.2 : 7.5,
          isActiveMonth ? hi : fg,
          isActiveMonth ? 1 : 0.70,
          isActiveMonth
        )
      }
      ctx.globalAlpha = 1
      ctx.textBaseline = "alphabetic"

      var earth = point(earthLongitude, 0.43)
      var earthAngle = earthLongitude * Math.PI / 180 - Math.PI / 2
      var moonAngle = earthAngle + Math.PI + phaseDegrees * Math.PI / 180
      var moonRadius = Math.max(16, Math.min(width, height) * 0.105)
      var moon = {
        x: earth.x + moonRadius * Math.cos(moonAngle),
        y: earth.y + moonRadius * 0.68 * Math.sin(moonAngle)
      }

      ctx.beginPath()
      ctx.moveTo(cx, cy)
      ctx.lineTo(earth.x, earth.y)
      ctx.lineTo(moon.x, moon.y)
      ctx.strokeStyle = fg
      ctx.globalAlpha = 0.20
      ctx.lineWidth = 1
      ctx.stroke()
      ctx.globalAlpha = 1

      circle(cx, cy, 11, "#f6c453", "#ffe49b")
      circle(earth.x, earth.y, 7, hi, fg)
      circle(moon.x, moon.y, 3.5, "#e8edf2", fg)

      ctx.font = "600 9px sans-serif"
      ctx.fillStyle = fg
      ctx.globalAlpha = 0.78
      ctx.textAlign = "center"
      ctx.fillText("SŪRYA", cx, cy + 25)
      ctx.fillText("PṚTHVĪ", earth.x, earth.y + 19)
      ctx.fillText("CANDRA", moon.x, moon.y - 10)
      ctx.font = "7px sans-serif"
      ctx.globalAlpha = 0.48
      ctx.fillText("INNER · 12 SAURA MĀSA    OUTER · 27 NAKṢATRA", cx, height - 3)
      ctx.globalAlpha = 1
    }
  }

  component MoonPhaseDiagram: Canvas {
    property real phaseDegrees: 0
    property color foreground: root.contentForeground
    property color accent: Color.accent

    onPhaseDegreesChanged: requestPaint()
    onForegroundChanged: requestPaint()
    onAccentChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      ctx.clearRect(0, 0, width, height)
      var cx = width / 2
      var cy = height / 2
      var radius = Math.max(8, Math.min(width, height) / 2 - 2)
      var phase = ((phaseDegrees % 360) + 360) % 360
      var waxing = phase < 180
      var steps = 36

      ctx.beginPath()
      ctx.arc(cx, cy, radius, 0, Math.PI * 2)
      ctx.fillStyle = "#11151a"
      ctx.fill()

      // Sample the terminator.  This gives the correct illuminated fraction
      // at new, quarter and full phases without storing bitmap assets.
      ctx.beginPath()
      for (var index = 0; index <= steps; index++) {
        var dy = -radius + 2 * radius * index / steps
        var halfWidth = Math.sqrt(Math.max(0, radius * radius - dy * dy))
        var boundary = waxing
          ? cx + Math.cos(phase * Math.PI / 180) * halfWidth
          : cx - Math.cos(phase * Math.PI / 180) * halfWidth
        if (index === 0) ctx.moveTo(boundary, cy + dy)
        else ctx.lineTo(boundary, cy + dy)
      }
      if (waxing) {
        for (var rightIndex = 0; rightIndex <= steps; rightIndex++) {
          var rightAngle = Math.PI / 2 - Math.PI * rightIndex / steps
          ctx.lineTo(cx + radius * Math.cos(rightAngle), cy + radius * Math.sin(rightAngle))
        }
      } else {
        for (var leftIndex = 0; leftIndex <= steps; leftIndex++) {
          var leftAngle = Math.PI / 2 + Math.PI * leftIndex / steps
          ctx.lineTo(cx + radius * Math.cos(leftAngle), cy + radius * Math.sin(leftAngle))
        }
      }
      ctx.closePath()
      ctx.fillStyle = "#edf0d0"
      ctx.fill()

      ctx.beginPath()
      ctx.arc(cx, cy, radius, 0, Math.PI * 2)
      ctx.strokeStyle = String(accent)
      ctx.globalAlpha = 0.82
      ctx.lineWidth = 1.5
      ctx.stroke()
      ctx.globalAlpha = 1
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
              && root.panchangData.solar_lunar && root.panchangData.solar_lunar.positions
            width: parent.width
            spacing: Style.space(5)
            SectionLabel { sectionText: "Solar · lunar · terra cycles" }

            Item {
              width: parent.width
              height: Style.space(300)

              OrbitDiagram {
                id: orbitDiagram
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                height: Style.space(235)
                earthLongitude: root.panchangData.status === "ok" && root.panchangData.solar_lunar.positions
                  ? root.panchangData.solar_lunar.positions.earth_orbit_degrees : 0
                phaseDegrees: root.panchangData.status === "ok" ? root.panchangData.solar_lunar.phase_degrees : 0
                moonSidereal: root.panchangData.status === "ok" && root.panchangData.solar_lunar.positions
                  ? root.panchangData.solar_lunar.positions.moon_sidereal_degrees : 0
                sunSidereal: root.panchangData.status === "ok" && root.panchangData.solar_lunar.positions
                  ? root.panchangData.solar_lunar.positions.sun_sidereal_degrees : 0
              }

              Item {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: orbitDiagram.bottom
                anchors.bottom: parent.bottom

                MoonPhaseDiagram {
                  id: compactMoonPhase
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  width: Style.space(52)
                  height: width
                  phaseDegrees: root.panchangData.status === "ok" ? root.panchangData.solar_lunar.phase_degrees : 0
                }

                Column {
                  anchors.left: compactMoonPhase.right
                  anchors.leftMargin: Style.space(10)
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: Style.space(2)

                  Text {
                    width: parent.width
                    text: root.panchangData.status === "ok"
                      ? root.panchangData.solar_lunar.phase_name + " · " + root.panchangData.solar_lunar.illumination_approx + "% lit · lunar day ~" + root.panchangData.solar_lunar.phase_age_approx_days
                      : ""
                    color: root.contentForeground
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                  }
                  Text {
                    width: parent.width
                    text: "Current Saura Māsa · " + root.panchangValue("Saura māsa")
                    color: Color.accent
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                  Text {
                    width: parent.width
                    text: "Current Nakṣatra · " + root.panchangValue("Nakṣatra") + "  ·  P./U. = Pūrvā/Uttarā"
                    color: Qt.darker(root.contentForeground, 1.30)
                    font.family: root.contentFontFamily
                    font.pixelSize: Style.font.caption
                  }
                }
              }
            }

            Text {
              width: parent.width
              wrapMode: Text.WordWrap
              text: "Ecliptic schematic, not to scale. The twelve inner labels are Lahiri Saura Māsa/rāśi sectors; the current month is accented. Pṛthvī is opposite the sidereal Sun, and the highlighted outer tick is Candra’s current nakṣatra division."
              color: Qt.darker(root.contentForeground, 1.55)
              font.family: root.contentFontFamily
              font.pixelSize: Style.font.caption
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
            DetailRow { entry: ({ label: "Moon phase", value: root.panchangData.status === "ok" ? root.panchangData.solar_lunar.phase_name + " · " + root.panchangData.solar_lunar.illumination_approx + "% illuminated" : "" }) }
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
