import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Compact top-bar label plus the owner of the location-aware Pañcāṅga panel.
// The clock itself is cheap and updates every minute.  Astronomy is a short
// child process at startup and then every 15 minutes, never on every tick.
BarWidget {
  id: root
  moduleName: "local.hindu-calendar"

  property date displayDate: clock.date
  property var panchangData: ({ status: "loading" })
  readonly property string launcherPath: Qt.resolvedUrl("engine/launch.sh").toString().replace(/^file:\/\//, "")
  readonly property bool use24Hour: panchangData.status === "ok" && panchangData.display
    ? panchangData.display.use_24_hour_time : setting("use24Hour", true)
  readonly property string timeText: Qt.formatTime(displayDate, use24Hour ? "HH:mm" : "h:mm AP")
  readonly property string dateText: Qt.formatDate(displayDate, "d MMM")
  readonly property string samvatText: panchangData.status === "ok" && panchangData.header
    ? "VS " + panchangData.header.vikram_samvat.year : ""
  readonly property string displayText: timeText + " · " + dateText + (samvatText !== "" ? " · " + samvatText : "")
  readonly property string statusText: panchangData.status === "unavailable"
    ? "Pañcāṅga unavailable: " + panchangData.error
    : (panchangData.status === "loading" ? "Calculating local Pañcāṅga…" : "Local Hindu calendar & Pañcāṅga")

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function parseEngineOutput(raw) {
    try {
      var result = JSON.parse(String(raw || ""))
      if (!result || typeof result !== "object") throw new Error("empty response")
      panchangData = result
    } catch (error) {
      panchangData = { status: "unavailable", error: "The local calendar engine returned invalid data." }
    }
  }

  function refreshPanchang() {
    if (!engineProcess.running) engineProcess.running = true
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("panchangData" in target) target.panchangData = root.panchangData
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  onPanchangDataChanged: injectPanel()

  Component.onCompleted: refreshPanchang()

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
    onDateChanged: root.displayDate = date
  }

  Timer {
    interval: 15 * 60 * 1000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: root.refreshPanchang()
  }

  Process {
    id: engineProcess
    command: ["bash", root.launcherPath]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.parseEngineOutput(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.panchangData.status === "loading")
        root.panchangData = { status: "unavailable", error: "The local calendar engine could not start." }
    }
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  IpcHandler {
    target: "local.hindu-calendar"
    function refresh(): void { root.refreshPanchang() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.vertical ? "☸" : root.displayText
    labelVisible: true
    tooltipText: root.statusText
    horizontalMargin: 8.75
    verticalPadding: 8.75
    onPressed: function(button) {
      if (button === Qt.MiddleButton) root.refreshPanchang()
      else root.togglePanel()
    }
  }
}
