const assert = require("node:assert/strict")
const timer = require("../TimerModel.js")

const presets = timer.presets()
assert.equal(presets[0].id, "pomodoro")
assert.equal(presets[0].seconds, 25 * 60)
assert.equal(timer.presetForId("half-murut").seconds, 24 * 60)
assert.equal(timer.presetForId("full-murut").seconds, 48 * 60)
assert.equal(timer.presetForId("missing").id, "pomodoro")

assert.equal(timer.formatTime(0), "00:00")
assert.equal(timer.formatTime(65), "01:05")
assert.equal(timer.formatDuration(65), "1m")
assert.equal(timer.formatDuration(3_900), "1h 5m")
assert.equal(timer.secondsRemaining(10_000, 9_001), 1)
assert.equal(timer.secondsRemaining(10_000, 10_000), 0)

assert.deepEqual(timer.stateFrom({
  selectedPresetId: "full-murut",
  status: "paused",
  heldRemainingSeconds: 1200
}), {
  selectedPresetId: "full-murut",
  status: "paused",
  deadlineMs: 0,
  heldRemainingSeconds: 1200,
  dailyMetrics: {},
  totalCompletedSessions: 0,
  totalFocusSeconds: 0
})

assert.deepEqual(timer.stateFrom({ status: "running", heldRemainingSeconds: 600 }), {
  selectedPresetId: "pomodoro",
  status: "paused",
  deadlineMs: 0,
  heldRemainingSeconds: 600,
  dailyMetrics: {},
  totalCompletedSessions: 0,
  totalFocusSeconds: 0
})

const daily = timer.recordCompletion({}, "2026-08-23", 25 * 60)
const dashboard = timer.dashboardMetrics(daily, "2026-08-23", 1, 25 * 60)
assert.deepEqual(daily, { "2026-08-23": { sessions: 1, focusSeconds: 1500 } })
assert.equal(dashboard.todaySessions, 1)
assert.equal(dashboard.todayFocusSeconds, 1500)
assert.equal(dashboard.streakDays, 1)
assert.equal(dashboard.lastSeven.length, 7)

console.log("Pomodoro timer model tests passed")
