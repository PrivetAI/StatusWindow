import SwiftUI

// MARK: - Palette
//
// Calm clinical: deep slate ink on warm off-white paper, soft teal as the working
// accent, a single amber for time-sensitive rows and one restrained red reserved
// exclusively for the post-exposure countdown.

enum SWTheme {
    static let ink        = Color(red: 0.145, green: 0.180, blue: 0.220) // 252E38
    static let paper      = Color(red: 0.969, green: 0.957, blue: 0.937) // F7F4EF
    static let card       = Color(red: 1.000, green: 0.996, blue: 0.988) // FFFEFC
    static let mist       = Color(red: 0.898, green: 0.902, blue: 0.894) // E5E6E4
    static let teal       = Color(red: 0.157, green: 0.478, blue: 0.451) // 287A73
    static let tealSoft   = Color(red: 0.855, green: 0.918, blue: 0.910) // DAEAE8
    static let amber      = Color(red: 0.776, green: 0.541, blue: 0.180) // C68A2E
    static let amberSoft  = Color(red: 0.976, green: 0.933, blue: 0.855) // F9EEDA
    static let alert      = Color(red: 0.686, green: 0.243, blue: 0.220) // AF3E38
    static let alertSoft  = Color(red: 0.973, green: 0.898, blue: 0.890) // F8E5E3
    static let indigo     = Color(red: 0.286, green: 0.325, blue: 0.482) // 49537B
    static let moss       = Color(red: 0.376, green: 0.478, blue: 0.310) // 607A4F

    static let inkSoft    = Color(red: 0.145, green: 0.180, blue: 0.220).opacity(0.62)
    static let inkFaint   = Color(red: 0.145, green: 0.180, blue: 0.220).opacity(0.34)
    static let hairline   = Color(red: 0.145, green: 0.180, blue: 0.220).opacity(0.11)
    static let cardEdge   = Color(red: 0.145, green: 0.180, blue: 0.220).opacity(0.07)

    /// Fixed colour chips a partner entry can be tagged with. Neutral, non-gendered.
    static let chips: [Color] = [
        Color(red: 0.157, green: 0.478, blue: 0.451), // teal
        Color(red: 0.286, green: 0.325, blue: 0.482), // indigo
        Color(red: 0.776, green: 0.541, blue: 0.180), // amber
        Color(red: 0.376, green: 0.478, blue: 0.310), // moss
        Color(red: 0.494, green: 0.353, blue: 0.478), // plum
        Color(red: 0.616, green: 0.427, blue: 0.318), // clay
        Color(red: 0.298, green: 0.451, blue: 0.545), // steel
        Color(red: 0.392, green: 0.404, blue: 0.427)  // graphite
    ]

    static let chipNames = ["Teal", "Indigo", "Amber", "Moss", "Plum", "Clay", "Steel", "Graphite"]

    static func chip(_ index: Int) -> Color {
        guard !chips.isEmpty else { return teal }
        let i = ((index % chips.count) + chips.count) % chips.count
        return chips[i]
    }

    static func chipName(_ index: Int) -> String {
        guard !chipNames.isEmpty else { return "Teal" }
        let i = ((index % chipNames.count) + chipNames.count) % chipNames.count
        return chipNames[i]
    }
}

// MARK: - Typography

enum SWFont {
    static func display(_ size: CGFloat = 26) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func title(_ size: CGFloat = 20) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func heading(_ size: CGFloat = 15) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func body(_ size: CGFloat = 14) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func bodyTight(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .regular, design: .rounded) }
    static func label(_ size: CGFloat = 11) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .medium, design: .monospaced) }
    static func monoLarge(_ size: CGFloat = 30) -> Font { .system(size: size, weight: .semibold, design: .monospaced) }
}

// MARK: - Safe arithmetic
//
// Nothing on screen may ever render as NaN or infinity. Every ratio in the app
// goes through here and an unrepresentable value falls back to an em dash.

enum SWMath {
    static func safeDivide(_ numerator: Double, _ denominator: Double) -> Double? {
        guard denominator != 0, denominator.isFinite, numerator.isFinite else { return nil }
        let value = numerator / denominator
        guard value.isFinite else { return nil }
        return value
    }

    static func percent(_ part: Int, of whole: Int) -> Double? {
        guard whole > 0 else { return nil }
        guard let ratio = safeDivide(Double(part), Double(whole)) else { return nil }
        return ratio * 100.0
    }

    static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        guard value.isFinite else { return lower }
        if lower > upper { return lower }
        return Swift.min(Swift.max(value, lower), upper)
    }

    static func clampInt(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        if lower > upper { return lower }
        return Swift.min(Swift.max(value, lower), upper)
    }
}

// MARK: - Dates
//
// Every date in this app is compared as an integer day key. Comparing `Date`
// values directly never matches, because the stored time of day differs.

enum SWDay {
    static var calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.timeZone = TimeZone.current
        return cal
    }()

    static func start(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    /// yyyymmdd as an Int — the canonical day identity used for equality everywhere.
    static func key(_ date: Date) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let y = parts.year ?? 2000
        let m = parts.month ?? 1
        let d = parts.day ?? 1
        return y * 10000 + m * 100 + d
    }

    static func adding(days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: start(date)) ?? start(date)
    }

    static func adding(months: Int, to date: Date) -> Date {
        calendar.date(byAdding: .month, value: months, to: start(date)) ?? start(date)
    }

    /// Whole days between two calendar days. Negative if `to` is before `from`.
    static func between(_ from: Date, _ to: Date) -> Int {
        let a = start(from)
        let b = start(to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func isSameDay(_ a: Date, _ b: Date) -> Bool { key(a) == key(b) }

    /// The first day of the week containing `date`, honouring the user's week-start
    /// preference (applied to this calendar by the store).
    static func startOfWeek(_ date: Date) -> Date {
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: start(date))
        return calendar.date(from: components).map { start($0) } ?? start(date)
    }

    /// Applies the week-start preference to every calendar computation in the app.
    static func setWeekStartsMonday(_ mondayFirst: Bool) {
        calendar.firstWeekday = mondayFirst ? 2 : 1
    }

    static var today: Date { start(Date()) }
}

// MARK: - Formatting
//
// Every formatter is pinned to en_US_POSIX so the interface can never reorder or
// change language with the phone's region setting.

enum SWFormat {

    static func makeFormatter(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = SWDay.calendar
        f.timeZone = TimeZone.current
        f.dateFormat = template
        return f
    }

    private static let dmy   = makeFormatter("d MMMM yyyy")
    private static let dmShort = makeFormatter("d MMM")
    private static let dmyShort = makeFormatter("d MMM yyyy")
    private static let mdy   = makeFormatter("MMMM d, yyyy")
    private static let mdyShort = makeFormatter("MMM d, yyyy")
    private static let iso   = makeFormatter("yyyy-MM-dd")
    private static let weekday = makeFormatter("EEEE")
    private static let weekdayShort = makeFormatter("EEE")
    private static let timeOnly = makeFormatter("HH:mm")
    private static let monthYear = makeFormatter("MMMM yyyy")

    /// Long form, respecting the user's chosen date style.
    static func long(_ date: Date, style: SWDateStyle) -> String {
        switch style {
        case .dayMonthYear: return dmy.string(from: date)
        case .monthDayYear: return mdy.string(from: date)
        case .isoNumeric:   return iso.string(from: date)
        }
    }

    static func medium(_ date: Date, style: SWDateStyle) -> String {
        switch style {
        case .dayMonthYear: return dmyShort.string(from: date)
        case .monthDayYear: return mdyShort.string(from: date)
        case .isoNumeric:   return iso.string(from: date)
        }
    }

    static func short(_ date: Date, style: SWDateStyle) -> String {
        switch style {
        case .dayMonthYear: return dmShort.string(from: date)
        case .monthDayYear: return dmShort.string(from: date)
        case .isoNumeric:   return iso.string(from: date)
        }
    }

    static func weekdayName(_ date: Date) -> String { weekday.string(from: date) }
    static func weekdayAbbrev(_ date: Date) -> String { weekdayShort.string(from: date) }
    static func clock(_ date: Date) -> String { timeOnly.string(from: date) }
    static func monthLabel(_ date: Date) -> String { monthYear.string(from: date) }

    static func percentString(_ value: Double?) -> String {
        guard let value = value, value.isFinite else { return "—" }
        return String(format: "%.0f%%", value)
    }

    static func dayCount(_ days: Int) -> String {
        if days == 1 { return "1 day" }
        return "\(days) days"
    }

    /// "in 12 days" / "12 days ago" / "today"
    static func relativeDay(_ target: Date, from reference: Date = Date()) -> String {
        let delta = SWDay.between(reference, target)
        if delta == 0 { return "today" }
        if delta == 1 { return "tomorrow" }
        if delta == -1 { return "yesterday" }
        if delta > 0 { return "in \(delta) days" }
        return "\(-delta) days ago"
    }

    /// Hours and minutes remaining, floor-safe.
    static func countdown(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0h 00m" }
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

// MARK: - Layout metrics

enum SWMetrics {
    static var screenWidth: CGFloat { UIScreen.main.bounds.width }
    static var screenHeight: CGFloat { UIScreen.main.bounds.height }
    /// True on 375x667-class hardware, where fixed hero layouts collapse.
    static var isCompactHeight: Bool { UIScreen.main.bounds.height <= 700 }
    static let tabBarHeight: CGFloat = 62
    static let scrollBottomInset: CGFloat = 36
    static let cardCorner: CGFloat = 16
    static let pagePadding: CGFloat = 16
}
