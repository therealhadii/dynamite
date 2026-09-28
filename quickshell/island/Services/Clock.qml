pragma Singleton

import Quickshell
import QtQuick

// The clock, and the two formats everything that draws a time uses.
//
// One pattern, and the reason is that the pill and the lock screen were
// formatting independently once and could not have been expected to
// agree: `time` and `timeLong` are the only two places a time string is
// built, and both read the pattern below.
//
// The formats are Apple's, per locale:
//
//   24-hour   09:41        `hh` is 00-23 with a leading zero
//   12-hour   9:41 AM      `h` unpadded, because 09:41 AM is not a
//                          thing anybody writes, and the meridiem is
//                          upper case to match en_US
//
// Which is `hh` and which is `h` is the whole subtlety, and getting it
// wrong is how a 12-hour clock ends up reading "09:41 AM".

Singleton {
    id: root

    readonly property string timePattern:
        Config.island.clock24h ? "hh:mm" : "h:mm AP"

    readonly property string timeLongPattern:
        Config.island.clock24h ? "hh:mm:ss" : "h:mm:ss AP"

    readonly property string time:
        Qt.formatDateTime(source.date, timePattern)
    readonly property string timeLong:
        Qt.formatDateTime(source.date, timeLongPattern)

    readonly property string date:
        Qt.formatDateTime(source.date, "ddd dd MMM")
    // The long form, and its only reader is the lock screen — the
    // control centre's card takes `date` instead.
    //
    // The year is gone and the day is unpadded, which is what the
    // login window it is copied from prints: a lock screen answers
    // "what day is it", and the year is the one part of the answer
    // nobody has ever needed while standing up. `d` rather than `dd`
    // because "Monday, 08 September" is a date in a database.
    readonly property string dateLong:
        Qt.formatDateTime(source.date, "dddd, d MMMM")

    // For arithmetic, not for drawing: the month card compares days and
    // the calendar keys events by it. Never a formatted string — that
    // would be a locale question in the middle of a comparison.
    readonly property date now: source.date

    // `yyyy-MM-dd` and nothing else, ever. A key, not a date a person
    // reads, and the one place in this file where the format is not a
    // presentation choice.
    readonly property string todayKey:
        Qt.formatDateTime(source.date, "yyyy-MM-dd")

    SystemClock {
        id: source
        precision: SystemClock.Seconds
    }
}
