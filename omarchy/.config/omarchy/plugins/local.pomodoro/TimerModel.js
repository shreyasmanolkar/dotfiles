// Pure timer and persistence helpers. Keeping the arithmetic here makes the
// QML host a small state owner rather than a second clock implementation.

var PRESETS = [
  { id: "pomodoro", label: "Pomodoro", shortLabel: "25 min", seconds: 25 * 60, description: "The classic 25-minute focus session." },
  { id: "eighth-murut", label: "⅛ Murut", shortLabel: "6 min", seconds: 6 * 60, description: "⅛ of a 48-minute Murut: a quick reset." },
  { id: "quarter-murut", label: "¼ Murut", shortLabel: "12 min", seconds: 12 * 60, description: "¼ of a 48-minute Murut." },
  { id: "half-murut", label: "½ Murut", shortLabel: "24 min", seconds: 24 * 60, description: "½ of a 48-minute Murut." },
  { id: "three-quarter-murut", label: "¾ Murut", shortLabel: "36 min", seconds: 36 * 60, description: "¾ of a 48-minute Murut." },
  { id: "full-murut", label: "1 Murut", shortLabel: "48 min", seconds: 48 * 60, description: "One traditional Murut (Muhūrta): 48 minutes." }
]

function presets() {
  return PRESETS.slice()
}

function presetForId(id) {
  var wanted = String(id || "")
  for (var index = 0; index < PRESETS.length; index++) {
    if (PRESETS[index].id === wanted) return PRESETS[index]
  }
  return PRESETS[0]
}

function clampSeconds(value, fallback, maximum) {
  var parsed = Math.round(Number(value))
  if (!isFinite(parsed) || parsed < 0) return fallback
  return Math.min(parsed, maximum || 24 * 60 * 60)
}

function secondsRemaining(deadlineMs, nowMs) {
  var deadline = Number(deadlineMs)
  var now = Number(nowMs)
  if (!isFinite(deadline) || !isFinite(now)) return 0
  return Math.max(0, Math.ceil((deadline - now) / 1000))
}

function formatTime(seconds) {
  var total = Math.max(0, Math.round(Number(seconds) || 0))
  var minutes = Math.floor(total / 60)
  var remainder = total % 60
  return String(minutes).padStart(2, "0") + ":" + String(remainder).padStart(2, "0")
}

function formatDuration(seconds) {
  var total = Math.max(0, Math.round(Number(seconds) || 0))
  var hours = Math.floor(total / 3600)
  var minutes = Math.floor((total % 3600) / 60)
  if (hours > 0) return hours + "h" + (minutes > 0 ? " " + minutes + "m" : "")
  return minutes + "m"
}

function dateKey(date) {
  var value = date instanceof Date ? date : new Date()
  return value.getFullYear() + "-" + String(value.getMonth() + 1).padStart(2, "0")
    + "-" + String(value.getDate()).padStart(2, "0")
}

function dateBefore(key, count) {
  var parts = String(key || "").split("-")
  var date = new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]))
  date.setDate(date.getDate() - Math.max(0, Math.round(Number(count) || 0)))
  return dateKey(date)
}

function wholeNumber(value, fallback) {
  var parsed = Math.floor(Number(value))
  return isFinite(parsed) && parsed >= 0 ? parsed : fallback
}

// One small record per calendar day, retained for the dashboard's recent
// trend and streak. The all-time counters are stored separately, so pruning
// old days keeps the state file small without losing lifetime totals.
function dailyMetricsFrom(raw) {
  var source = raw && typeof raw === "object" ? raw : ({})
  var valid = ({})
  var keys = Object.keys(source).sort()
  for (var index = 0; index < keys.length; index++) {
    var key = keys[index]
    if (!/^\d{4}-\d{2}-\d{2}$/.test(key)) continue
    var entry = source[key] || ({})
    var sessions = wholeNumber(entry.sessions, 0)
    var focusSeconds = wholeNumber(entry.focusSeconds, 0)
    if (sessions > 0 || focusSeconds > 0) valid[key] = { sessions: sessions, focusSeconds: focusSeconds }
  }
  var retained = Object.keys(valid).sort().slice(-365)
  var result = ({})
  for (var item = 0; item < retained.length; item++) result[retained[item]] = valid[retained[item]]
  return result
}

function recordCompletion(daily, key, seconds) {
  var result = dailyMetricsFrom(daily)
  var day = /^\d{4}-\d{2}-\d{2}$/.test(String(key || "")) ? String(key) : dateKey(new Date())
  var previous = result[day] || { sessions: 0, focusSeconds: 0 }
  result[day] = {
    sessions: previous.sessions + 1,
    focusSeconds: previous.focusSeconds + Math.max(0, Math.round(Number(seconds) || 0))
  }
  return dailyMetricsFrom(result)
}

function dashboardMetrics(daily, todayKey, totalSessions, totalFocusSeconds) {
  var days = dailyMetricsFrom(daily)
  var today = /^\d{4}-\d{2}-\d{2}$/.test(String(todayKey || "")) ? String(todayKey) : dateKey(new Date())
  var todayEntry = days[today] || { sessions: 0, focusSeconds: 0 }
  var completed = wholeNumber(totalSessions, 0)
  var focus = wholeNumber(totalFocusSeconds, 0)
  var streak = 0
  while (days[dateBefore(today, streak)] && days[dateBefore(today, streak)].sessions > 0) streak++

  var lastSeven = []
  var weeklyMaximum = 0
  for (var offset = 6; offset >= 0; offset--) {
    var key = dateBefore(today, offset)
    var entry = days[key] || { sessions: 0, focusSeconds: 0 }
    weeklyMaximum = Math.max(weeklyMaximum, entry.focusSeconds)
    lastSeven.push({ key: key, sessions: entry.sessions, focusSeconds: entry.focusSeconds })
  }

  return {
    todaySessions: todayEntry.sessions,
    todayFocusSeconds: todayEntry.focusSeconds,
    totalSessions: completed,
    totalFocusSeconds: focus,
    averageFocusSeconds: completed > 0 ? Math.round(focus / completed) : 0,
    streakDays: streak,
    weeklyMaximum: weeklyMaximum,
    lastSeven: lastSeven
  }
}

function validStatus(value) {
  var status = String(value || "")
  return status === "ready" || status === "running" || status === "paused" || status === "complete"
    ? status : "ready"
}

// Normalise the small state document read from XDG_STATE_HOME. Corrupt or
// old files always fall back to a safe, stopped Pomodoro rather than making
// the bar widget fail to load.
function stateFrom(raw) {
  var source = raw && typeof raw === "object" ? raw : ({})
  var preset = presetForId(source.selectedPresetId)
  var status = validStatus(source.status)
  var held = clampSeconds(source.heldRemainingSeconds, preset.seconds)
  var deadline = Number(source.deadlineMs)
  var daily = dailyMetricsFrom(source.dailyMetrics)
  var totalSessions = wholeNumber(source.totalCompletedSessions, 0)
  var totalFocusSeconds = wholeNumber(source.totalFocusSeconds, 0)
  if (!isFinite(deadline) || deadline <= 0) deadline = 0

  if (status === "ready") held = preset.seconds
  if (status === "complete") held = 0
  if (status === "running" && deadline === 0) {
    status = "paused"
    held = held > 0 ? held : preset.seconds
  }

  return {
    selectedPresetId: preset.id,
    status: status,
    deadlineMs: deadline,
    heldRemainingSeconds: held,
    dailyMetrics: daily,
    totalCompletedSessions: totalSessions,
    totalFocusSeconds: totalFocusSeconds
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    presets: presets,
    presetForId: presetForId,
    secondsRemaining: secondsRemaining,
    formatTime: formatTime,
    formatDuration: formatDuration,
    dateKey: dateKey,
    dailyMetricsFrom: dailyMetricsFrom,
    recordCompletion: recordCompletion,
    dashboardMetrics: dashboardMetrics,
    stateFrom: stateFrom
  }
}
