import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "CliampModel.js" as CliampModel

// A persistent, deliberately low-cost controller. Status is polled over
// Cliamp's local IPC socket every two seconds. On startup it launches the
// headless Cliamp daemon, so the controller never needs a TUI window.
BarWidget {
  id: root
  moduleName: "shreyas.cliamp"

  property var player: CliampModel.unavailable()
  property var playlists: []
  property bool playlistsLoaded: false
  property string serviceStatus: ""
  readonly property string servicePath: Qt.resolvedUrl("CliampService.sh").toString().replace(/^file:\/\//, "")
  readonly property bool playing: player.available && player.state === "playing"
  readonly property bool paused: player.available && player.state === "paused"
  readonly property string stateIcon: playing ? "▶" : (paused ? "Ⅱ" : "♫")
  // A fixed bar slot means neither a longer track name nor the play/pause
  // glyph can shift the widgets that follow this controller.
  readonly property real barSlotWidth: Style.space(190)
  readonly property string barText: vertical ? stateIcon : stateIcon + " " + CliampModel.compact(player.title, 20)
  readonly property string tooltipText: player.available
    ? player.title + " — " + player.artist
      + "\nLeft click: controls · Middle: play/pause · Right: ensure background player"
    : "Cliamp is starting in the background\nLeft click: controls · Right click: retry"

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false
  readonly property real openPanelIndicatorWidth: button.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function setStatus(raw) {
    player = CliampModel.statusFrom(raw)
  }

  function refreshStatus() {
    if (!statusProcess.running) statusProcess.running = true
  }

  function refreshPlaylists() {
    if (!playlistProcess.running) playlistProcess.running = true
  }

  function runCliamp(arguments) {
    // execDetached is the most reliable choice for an immediate user action:
    // it is not coupled to a particular bar instance or an open panel.
    Quickshell.execDetached(["cliamp"].concat(arguments))
    refreshDelay.restart()
  }

  function runService(action, provider, playlist) {
    if (serviceProcess.running) return
    serviceStatus = action === "restart" ? "Switching source…" : "Starting Cliamp in the background…"
    serviceProcess.command = ["bash", servicePath, action, String(provider || ""), String(playlist || "")]
    serviceProcess.running = true
  }

  function ensurePlayer(playlist) { runService("start", "", playlist || "") }
  function switchSource(source) { runService("restart", String(source || ""), "") }

  function togglePlayback() { runCliamp([playing ? "pause" : "play"]) }
  function previousTrack() { runCliamp(["prev"]) }
  function nextTrack() { runCliamp(["next"]) }
  function seekBy(seconds) { runCliamp(["seek", String(Math.round(seconds))]) }
  function seekToRatio(ratio) {
    if (!player.available || !(player.duration > 0)) return
    var target = Math.max(0, Math.min(player.duration, player.duration * ratio))
    seekBy(target - player.position)
  }
  function adjustVolume(delta) {
    if (!player.available) return
    var next = Math.max(-30, Math.min(6, Number(player.volume || 0) + delta))
    runCliamp(["volume", String(next)])
  }
  function toggleShuffle() { runCliamp(["shuffle", "toggle"]) }
  function cycleRepeat() { runCliamp(["repeat", "cycle"]) }
  function loadPlaylist(name) {
    if (!name) return
    if (player.available) {
      runCliamp(["load", String(name)])
      return
    }
    ensurePlayer(String(name))
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  function open() {
    refreshStatus()
    refreshPlaylists()
    ensurePlayer()
    if (panelLoader.item) panelLoader.item.open()
  }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function togglePanel() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()

  Process {
    id: statusProcess
    command: ["cliamp", "status", "--json"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.setStatus(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.player = CliampModel.unavailable("Start Cliamp to connect.")
    }
  }

  Process {
    id: playlistProcess
    command: ["cliamp", "playlist", "list"]
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.playlists = CliampModel.playlistsFrom(text)
        root.playlistsLoaded = true
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.playlistsLoaded = true
    }
  }

  Process {
    id: serviceProcess
    running: false
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.serviceStatus = String(text || "").trim()
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.serviceStatus === "")
        root.serviceStatus = "Cliamp background service could not start."
      refreshDelay.restart()
    }
  }

  Timer {
    id: pollTimer
    interval: 2000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refreshStatus()
  }

  Timer {
    id: refreshDelay
    interval: 220
    repeat: false
    onTriggered: {
      root.refreshStatus()
      root.refreshPlaylists()
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

  Component.onCompleted: {
    refreshStatus()
    refreshPlaylists()
    ensurePlayer()
  }

  IpcHandler {
    target: "shreyas.cliamp"
    function refresh(): void { root.refreshStatus() }
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.togglePanel() }
    function playPause(): void { root.togglePlayback() }
    function previous(): void { root.previousTrack() }
    function next(): void { root.nextTrack() }
    function start(): void { root.ensurePlayer() }
    function source(provider: string): void { root.switchSource(provider) }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.barText
    labelVisible: true
    fontSize: Style.font.body
    fixedWidth: root.vertical ? -1 : root.barSlotWidth
    horizontalMargin: 8.75
    verticalPadding: 7
    tooltipText: root.tooltipText
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.MiddleButton) root.togglePlayback()
      else if (buttonCode === Qt.RightButton) root.ensurePlayer()
      else root.togglePanel()
    }
  }
}
