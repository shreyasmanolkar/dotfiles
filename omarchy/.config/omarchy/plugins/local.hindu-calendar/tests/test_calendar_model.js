const assert = require("node:assert/strict")
const calendar = require("../CalendarModel.js")

const august = calendar.monthCells(2026, 7)
assert.equal(august.length, 42)
assert.equal(august[0].date.getDay(), 0)
assert.equal(august[0].day, 26)
assert.equal(august[6].day, 1)
assert.equal(august.filter(cell => cell.inMonth).length, 31)

const decemberForward = calendar.stepMonth(2026, 11, 1)
assert.deepEqual(decemberForward, { year: 2027, month: 0 })
assert.equal(calendar.sameDay(new Date(2026, 7, 22), new Date(2026, 7, 22)), true)
assert.equal(calendar.sameDay(new Date(2026, 7, 22), new Date(2026, 7, 23)), false)

console.log("Gregorian calendar model tests passed")
