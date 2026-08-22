// Pure Gregorian month-grid helpers.  This stays separate from Panel.qml so
// month navigation is deterministic and can be exercised without Quickshell.

function dateKey(date) {
  var year = date.getFullYear()
  var month = String(date.getMonth() + 1).padStart(2, "0")
  var day = String(date.getDate()).padStart(2, "0")
  return year + "-" + month + "-" + day
}

function sameDay(a, b) {
  return a && b && dateKey(a) === dateKey(b)
}

// Sunday-first is deliberate: this is the familiar civil-calendar view, not
// a replacement for location-dependent Pañcāṅga day boundaries.
function monthCells(year, month) {
  var first = new Date(year, month, 1)
  var cursor = new Date(year, month, 1 - first.getDay())
  var cells = []
  for (var index = 0; index < 42; index++) {
    var value = new Date(cursor)
    cells.push({
      date: value,
      year: value.getFullYear(),
      month: value.getMonth(),
      day: value.getDate(),
      inMonth: value.getFullYear() === year && value.getMonth() === month,
      weekend: value.getDay() === 0 || value.getDay() === 6
    })
    cursor.setDate(cursor.getDate() + 1)
  }
  return cells
}

function stepMonth(year, month, delta) {
  var date = new Date(year, month + delta, 1)
  return { year: date.getFullYear(), month: date.getMonth() }
}

if (typeof module !== "undefined") {
  module.exports = { dateKey: dateKey, sameDay: sameDay, monthCells: monthCells, stepMonth: stepMonth }
}
