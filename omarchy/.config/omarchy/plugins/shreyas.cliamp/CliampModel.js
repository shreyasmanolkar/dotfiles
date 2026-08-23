function unavailable(error) {
  return {
    available: false,
    error: String(error || "Start Cliamp to connect."),
    state: "stopped",
    title: "Cliamp is not running",
    artist: "Open the player to start listening.",
    album: "",
    playlist: "",
    position: 0,
    duration: 0,
    volume: 0,
    index: 0,
    total: 0,
    shuffle: false,
    repeat: "off"
  }
}

function statusFrom(raw) {
  var payload
  try {
    payload = JSON.parse(String(raw || ""))
  } catch (error) {
    return unavailable("Cliamp did not return a readable status.")
  }

  if (!payload || payload.ok !== true)
    return unavailable(payload && payload.error ? payload.error : "Cliamp is not running.")

  var track = payload.track || ({})
  var state = String(payload.state || "stopped").toLowerCase()
  return {
    available: true,
    error: "",
    state: state,
    title: String(track.title || (state === "stopped" ? "Nothing playing" : "Unknown track")),
    artist: String(track.artist || track.album || "Cliamp"),
    album: String(track.album || ""),
    playlist: String(payload.playlist || ""),
    position: finiteNumber(payload.position),
    duration: finiteNumber(payload.duration),
    volume: finiteNumber(payload.volume),
    index: Math.max(0, Math.round(finiteNumber(payload.index))),
    total: Math.max(0, Math.round(finiteNumber(payload.total))),
    shuffle: payload.shuffle === true,
    repeat: String(payload.repeat || "off").toLowerCase()
  }
}

function finiteNumber(value) {
  var number = Number(value)
  return isFinite(number) ? number : 0
}

function formatDuration(value) {
  var seconds = Math.max(0, Math.round(finiteNumber(value)))
  var minutes = Math.floor(seconds / 60)
  var hours = Math.floor(minutes / 60)
  var remainder = seconds % 60
  if (hours > 0)
    return hours + ":" + String(minutes % 60).padStart(2, "0") + ":" + String(remainder).padStart(2, "0")
  return minutes + ":" + String(remainder).padStart(2, "0")
}

function compact(text, limit) {
  var value = String(text || "")
  var maximum = Math.max(1, Math.round(finiteNumber(limit)))
  return value.length > maximum ? value.slice(0, Math.max(1, maximum - 1)) + "…" : value
}

function playlistsFrom(raw) {
  var result = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var match = lines[i].match(/^\s*(.*?)\s+(\d+)\s+tracks?\s*$/i)
    if (!match || !match[1]) continue
    result.push({ name: match[1], trackCount: Number(match[2]) || 0 })
  }
  return result
}
