import QtQuick
import QtQuick.Controls as Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "CliampModel.js" as CliampModel

// The panel owns no playback state. BarWidget.qml remains the single source
// of truth, which keeps an open panel, bar label, and IPC callers in sync.
Panel {
  id: root
  moduleName: "shreyas.cliamp"
  ipcTarget: "shreyas.cliamp"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var playerController: hostWidget
  readonly property var player: playerController ? playerController.player : CliampModel.unavailable()
  readonly property var barIdentity: hostWidget || root
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(foreground, 1.45)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property real progress: player.duration > 0
    ? Math.max(0, Math.min(1, player.position / player.duration)) : 0
  readonly property string primaryLabel: player.state === "playing" ? "Pause" : "Play"
  readonly property string primaryIcon: player.state === "playing" ? "Ⅱ" : "▶"
  readonly property string servicePath: Qt.resolvedUrl("CliampService.sh").toString().replace(/^file:\/\//, "")
  property string serviceStatus: ""

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
  function refresh() {
    if (!playerController) return
    playerController.refreshStatus()
    playerController.refreshPlaylists()
  }
  function runCliamp(arguments) {
    Quickshell.execDetached(["cliamp"].concat(arguments))
    if (playerController) Qt.callLater(playerController.refreshStatus)
  }
  function playPause() { runCliamp([player.state === "playing" ? "pause" : "play"]) }
  function previousTrack() { runCliamp(["prev"]) }
  function nextTrack() { runCliamp(["next"]) }
  function seekBy(seconds) { runCliamp(["seek", String(Math.round(seconds))]) }
  function seekToRatio(ratio) {
    if (!(player.duration > 0)) return
    var target = Math.max(0, Math.min(player.duration, player.duration * ratio))
    seekBy(target - player.position)
  }
  function adjustVolume(delta) {
    var next = Math.max(-30, Math.min(6, Number(player.volume || 0) + delta))
    runCliamp(["volume", String(next)])
  }
  function toggleShuffle() { runCliamp(["shuffle", "toggle"]) }
  function cycleRepeat() { runCliamp(["repeat", "cycle"]) }
  function loadPlaylist(name) {
    if (player.available) runCliamp(["load", String(name)])
    else runService("start", "", String(name))
  }
  function runService(action, provider, playlist) {
    if (serviceProcess.running) return
    serviceStatus = action === "restart" ? "Switching source…" : "Starting Cliamp in the background…"
    serviceProcess.command = ["bash", servicePath, action, String(provider || ""), String(playlist || "")]
    serviceProcess.running = true
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(410))
    // The card stays the same size while track metadata and playback state
    // change. Overflow is already handled by the Flickable below.
    contentHeight: panel.cappedContentHeight(Style.space(650))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onActivateRequested: root.playPause()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(text) {
        if (text === "j" || text === "J") root.previousTrack()
        else if (text === "l" || text === "L") root.nextTrack()
        else if (text === "p" || text === "P") root.playPause()
        else if (text === "s" || text === "S") root.toggleShuffle()
        else if (text === "r" || text === "R") root.cycleRepeat()
        else if (text === "o" || text === "O") root.runService("start", "", "")
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
            title: root.player.available ? root.player.title : "Cliamp is offline"
            meta: root.player.available ? root.player.artist : "START OR FOCUS THE PLAYER"
            detail: root.player.available
              ? (root.player.playlist !== "" ? CliampModel.playlistLabel(root.player.playlist) : root.player.state.toUpperCase())
              : root.player.error
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                text: root.player.state === "playing" ? "▶" : (root.player.state === "paused" ? "Ⅱ" : "♫")
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
          }

          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.player.available

            Text {
              width: parent.width
              text: root.player.album
              height: Style.space(18)
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Row {
              width: parent.width
              Text {
                id: leftTime
                width: implicitWidth
                text: CliampModel.formatDuration(root.player.position)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
              Item { width: Math.max(1, parent.width - leftTime.width - rightTime.width) }
              Text {
                id: rightTime
                text: CliampModel.formatDuration(root.player.duration)
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              width: parent.width
              height: Style.space(7)
              radius: height / 2
              color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.16)
              Rectangle {
                width: parent.width * root.progress
                height: parent.height
                radius: parent.radius
                color: Color.accent
              }
              MouseArea {
                anchors.fill: parent
                enabled: root.player.duration > 0
                hoverEnabled: true
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: function(mouse) { root.seekToRatio(mouse.x / width) }
              }
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(7)
            Button {
              width: (parent.width - parent.spacing * 2) / 3
              text: "Previous"
              iconText: "↶"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.previousTrack()
            }
            Button {
              width: (parent.width - parent.spacing * 2) / 3
              text: root.primaryLabel
              iconText: root.primaryIcon
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              selected: true
              onClicked: root.playPause()
            }
            Button {
              width: (parent.width - parent.spacing * 2) / 3
              text: "Next"
              iconText: "↷"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.nextTrack()
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(7)
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "-15s"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.seekBy(-15)
            }
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "+15s"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.seekBy(15)
            }
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "Shuffle"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              selected: root.player.shuffle
              onClicked: root.toggleShuffle()
            }
            Button {
              width: (parent.width - parent.spacing * 3) / 4
              text: "Repeat " + (root.player.repeat === "off" ? "" : root.player.repeat)
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              selected: root.player.repeat !== "off"
              onClicked: root.cycleRepeat()
            }
          }

          Row {
            width: parent.width
            spacing: Style.space(7)
            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Volume −"
              iconText: "−"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.adjustVolume(-2)
            }
            Button {
              width: (parent.width - parent.spacing) / 2
              text: "Volume +"
              iconText: "+"
              foreground: root.foreground
              accent: Color.accent
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.adjustVolume(2)
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "SOURCES"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              width: parent.width
              text: "Play your local Music folder or switch the controller's headless player between services. A separately launched Cliamp session is never stopped or replaced."
              wrapMode: Text.WordWrap
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Grid {
              width: parent.width
              columns: 2
              rowSpacing: Style.space(7)
              columnSpacing: Style.space(7)
              Repeater {
                model: [
                  { label: "Music folder", playlist: "youtube-audios" },
                  { label: "Radio", source: "radio" },
                  { label: "Spotify", source: "spotify" },
                  { label: "Default", source: "" }
                ]
                delegate: Button {
                  width: (parent.width - parent.columnSpacing) / parent.columns
                  text: modelData.label
                  iconText: modelData.playlist ? "▶" : (modelData.source === "" ? "⌕" : "↗")
                  foreground: root.foreground
                  accent: Color.accent
                  fontFamily: root.fontFamily
                  bordered: true
                  onClicked: {
                    if (modelData.playlist) root.loadPlaylist(modelData.playlist)
                    else root.runService("restart", modelData.source, "")
                  }
                }
              }
            }
          }

          PanelSeparator { foreground: root.foreground }

          Column {
            width: parent.width
            spacing: Style.space(7)

            PanelSectionHeader {
              text: "LOCAL PLAYLISTS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }
            Text {
              width: parent.width
              visible: root.playerController && !root.playerController.playlistsLoaded
              text: "Loading local playlists…"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Text {
              width: parent.width
              visible: root.playerController && root.playerController.playlistsLoaded && root.playerController.playlists.length === 0
              text: "No local playlists yet. Open Cliamp to create or import one."
              wrapMode: Text.WordWrap
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
            Repeater {
              model: root.playerController ? root.playerController.playlists : []
              delegate: Button {
                width: parent.width
                text: modelData.label + " · " + modelData.trackCount + " track" + (modelData.trackCount === 1 ? "" : "s")
                iconText: "▶"
                foreground: root.foreground
                accent: Color.accent
                fontFamily: root.fontFamily
                bordered: true
                onClicked: root.loadPlaylist(modelData.name)
              }
            }
          }

          Button {
            width: parent.width
            text: root.player.available ? "Background player ready" : "Start background player"
            iconText: root.player.available ? "✓" : "▶"
            foreground: root.foreground
            accent: Color.accent
            fontFamily: root.fontFamily
            bordered: true
            selected: true
            onClicked: root.runService("start", "", "")
          }

          Text {
            width: parent.width
            text: root.serviceStatus
            visible: text !== ""
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Text {
            width: parent.width
            text: "Keys: J/L previous/next · P play/pause · S shuffle · R repeat · O start background player"
            wrapMode: Text.WordWrap
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
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
              if (root.playerController) Qt.callLater(root.playerController.refreshStatus)
            }
          }
        }
      }
    }
  }
}
