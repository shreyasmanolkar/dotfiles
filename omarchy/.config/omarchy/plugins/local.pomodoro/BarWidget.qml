import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "TimerModel.js" as TimerModel

// The timer's single source of truth. The countdown is based on a wall-clock
// deadline, not on the QML tick count, so it remains accurate after suspend
// and across an omarchy-shell restart.
BarWidget {
  id: root
  moduleName: "local.pomodoro"

  readonly property string home: Quickshell.env("HOME") || ""
  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"
  readonly property string stateDir: stateHome + "/omarchy"
  readonly property string statePath: stateDir + "/pomodoro.json"
  readonly property string omarchyPath: Quickshell.env("OMARCHY_PATH") || "/usr/share/omarchy"

  PersistentProperties {
    id: persisted
    reloadableId: "local-pomodoro"
    property string selectedPresetId: "pomodoro"
    property string status: "ready"
    property double deadlineMs: 0
    property int heldRemainingSeconds: 25 * 60
    property var dailyMetrics: ({})
    property int totalCompletedSessions: 0
    property int totalFocusSeconds: 0
  }

  property alias selectedPresetId: persisted.selectedPresetId
  property alias status: persisted.status
  property alias deadlineMs: persisted.deadlineMs
  property alias heldRemainingSeconds: persisted.heldRemainingSeconds
  property alias dailyMetrics: persisted.dailyMetrics
  property alias totalCompletedSessions: persisted.totalCompletedSessions
  property alias totalFocusSeconds: persisted.totalFocusSeconds
  property bool stateLoaded: false
  property int clockRevision: 0
  property string currentDayKey: TimerModel.dateKey(new Date())
  readonly property var presets: TimerModel.presets()
  readonly property var selectedPreset: TimerModel.presetForId(selectedPresetId)
  readonly property int selectedDurationSeconds: selectedPreset.seconds
  readonly property int remainingSeconds: {
    clockRevision
    return status === "running"
      ? TimerModel.secondsRemaining(deadlineMs, Date.now())
      : Math.max(0, heldRemainingSeconds)
  }
  readonly property string remainingText: TimerModel.formatTime(remainingSeconds)
  readonly property real progress: selectedDurationSeconds > 0
    ? Math.max(0, Math.min(1, 1 - remainingSeconds / selectedDurationSeconds)) : 0
  readonly property int sessionElapsedSeconds: Math.max(0, selectedDurationSeconds - remainingSeconds)
  readonly property var dashboard: TimerModel.dashboardMetrics(
    dailyMetrics, currentDayKey, totalCompletedSessions, totalFocusSeconds)
  readonly property bool isRunning: status === "running"
  readonly property bool isPaused: status === "paused"
  readonly property bool isComplete: status === "complete"
  readonly property string statusGlyph: isRunning ? "●" : (isPaused ? "Ⅱ" : (isComplete ? "✓" : "◷"))
  readonly property string statusLabel: isRunning ? "FOCUSING" : (isPaused ? "PAUSED" : (isComplete ? "COMPLETE" : "READY"))
  readonly property string primaryActionLabel: isRunning ? "Pause" : (isPaused ? "Resume" : (isComplete ? "Start again" : "Start"))
  readonly property string primaryActionIcon: isRunning ? "Ⅱ" : "▶"
  readonly property color stateColor: isRunning || isComplete ? Color.accent
    : (isPaused ? Qt.darker(bar ? bar.barForeground : Color.foreground, 1.35) : (bar ? bar.barForeground : Color.foreground))
  readonly property string displayText: vertical
    ? statusGlyph + "\n" + remainingText : statusGlyph + " " + remainingText
  readonly property string tooltipText: isRunning
    ? "Focusing · " + remainingText + " left\nLeft click: controls · Middle: pause · Right: reset"
    : (isPaused
      ? "Paused · " + remainingText + " remaining\nLeft click: controls · Middle: resume · Right: reset"
      : (isComplete
        ? "Session complete · select or start another session"
        : "Ready · " + selectedPreset.label + " · " + remainingText + "\nLeft click: controls · Middle: start"))

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.labelWidth
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function persistState() {
    if (!stateLoaded) return
    stateFile.setText(JSON.stringify({
      version: 1,
      selectedPresetId: selectedPresetId,
      status: status,
      deadlineMs: deadlineMs,
      heldRemainingSeconds: heldRemainingSeconds,
      dailyMetrics: dailyMetrics,
      totalCompletedSessions: totalCompletedSessions,
      totalFocusSeconds: totalFocusSeconds
    }, null, 2) + "\n")
  }

  function loadState(raw) {
    if (stateLoaded) return
    var parsed = ({})
    try { parsed = JSON.parse(String(raw || "{}")) } catch (error) {
      console.warn("pomodoro: ignoring invalid saved state")
    }
    var next = TimerModel.stateFrom(parsed)
    selectedPresetId = next.selectedPresetId
    status = next.status
    deadlineMs = next.deadlineMs
    heldRemainingSeconds = next.heldRemainingSeconds
    dailyMetrics = next.dailyMetrics
    totalCompletedSessions = next.totalCompletedSessions
    totalFocusSeconds = next.totalFocusSeconds
    stateLoaded = true
    Qt.callLater(syncClock)
  }

  function syncClock() {
    clockRevision++
    if (status === "running" && remainingSeconds <= 0) finishTimer(true)
  }

  function selectPreset(id) {
    var preset = TimerModel.presetForId(id)
    selectedPresetId = preset.id
    resetTimer()
  }

  function selectPresetAt(index) {
    var position = Math.round(Number(index))
    if (position >= 0 && position < presets.length) selectPreset(presets[position].id)
  }

  function startTimer() {
    if (status === "running") return
    if (status === "complete") heldRemainingSeconds = selectedDurationSeconds
    if (heldRemainingSeconds <= 0) heldRemainingSeconds = selectedDurationSeconds
    deadlineMs = Date.now() + heldRemainingSeconds * 1000
    status = "running"
    syncClock()
    persistState()
  }

  function pauseTimer() {
    if (status !== "running") return
    syncClock()
    if (status !== "running") return
    heldRemainingSeconds = Math.max(1, remainingSeconds)
    deadlineMs = 0
    status = "paused"
    persistState()
  }

  function primaryAction() {
    if (status === "running") pauseTimer()
    else startTimer()
  }

  function resetTimer() {
    deadlineMs = 0
    heldRemainingSeconds = selectedDurationSeconds
    status = "ready"
    clockRevision++
    persistState()
  }

  function finishTimer(notify) {
    if (status !== "running") return
    deadlineMs = 0
    heldRemainingSeconds = 0
    status = "complete"
    dailyMetrics = TimerModel.recordCompletion(dailyMetrics, currentDayKey, selectedDurationSeconds)
    totalCompletedSessions++
    totalFocusSeconds += selectedDurationSeconds
    persistState()
    if (notify) {
      Quickshell.execDetached([
        omarchyPath + "/bin/omarchy-notification-send",
        "-u", "normal", "-g", "✓",
        "Focus session complete",
        selectedPreset.label + " is complete. Take a breath before the next one."
      ])
    }
  }

  function endTimeText() {
    return isRunning && deadlineMs > 0 ? "Ends at " + Qt.formatTime(new Date(deadlineMs), "HH:mm") : ""
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: ensureStateDir
    command: ["mkdir", "-p", root.stateDir]
    running: false
  }

  FileView {
    id: stateFile
    path: root.statePath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadState(text())
    onLoadFailed: root.loadState("")
  }

  Timer {
    interval: 250
    repeat: true
    running: root.isRunning
    onTriggered: root.syncClock()
  }

  SystemClock {
    id: dayClock
    precision: SystemClock.Minutes
    onDateChanged: root.currentDayKey = TimerModel.dateKey(date)
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

  Component.onCompleted: {
    ensureStateDir.running = true
    Qt.callLater(function() { stateFile.reload() })
  }

  IpcHandler {
    target: "local.pomodoro"
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function start(): void { root.startTimer() }
    function pause(): void { root.pauseTimer() }
    function resume(): void { root.startTimer() }
    function reset(): void { root.resetTimer() }
    function preset(id: string): void { root.selectPreset(id) }
    function status(): string {
      return JSON.stringify({
        status: root.status,
        preset: root.selectedPreset.id,
        remainingSeconds: root.remainingSeconds
      })
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.displayText
    fontSize: Style.font.body
    labelVisible: true
    fixedHeight: root.vertical ? Style.bar.iconSlot * 2 : -1
    horizontalMargin: 8.75
    verticalPadding: 5.5
    foreground: root.stateColor
    tooltipText: root.tooltipText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.primaryAction()
      else if (buttonCode === Qt.RightButton) root.resetTimer()
      else root.togglePanel()
    }
  }
}
