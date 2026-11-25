import Foundation

/// Format rupiah dan tanggal (bahasa Indonesia).
enum Fmt {
    private static let numberFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        f.maximumFractionDigits = 0
        return f
    }()

    static func group(_ value: Double) -> String {
        return numberFormatter.string(from: NSNumber(value: Int(value.rounded()))) ?? String(Int(value.rounded()))
    }

    static func money(_ value: Double) -> String {
        return "Rp " + group(value)
    }

    /// 1.250.000 menjadi "1,3 jt", 450.000 menjadi "450 rb".
    static func short(_ value: Double) -> String {
        if value >= 1_000_000 {
            let s = String(format: "%.1f", value / 1_000_000).replacingOccurrences(of: ".", with: ",")
            return s.replacingOccurrences(of: ",0", with: "") + " jt"
        }
        if value >= 1_000 { return String(Int((value / 1_000).rounded())) + " rb" }
        return value > 0 ? String(Int(value)) : ""
    }

    static func qty(_ value: Double) -> String {
        if value == value.rounded() { return String(Int(value)) }
        return String(format: "%.2f", value).replacingOccurrences(of: ".", with: ",")
    }

    private static let isoFull: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String) -> Date? {
        return isoFull.date(from: s) ?? isoPlain.date(from: s)
    }

    static func iso(_ d: Date) -> String {
        return isoFull.string(from: d)
    }

    private static let display: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMM yyyy, HH.mm"
        return f
    }()
    private static let dayOnly: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f
    }()
    private static let ymd: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let weekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "EEE"
        return f
    }()

    static func dateTime(_ s: String) -> String {
        guard let d = parse(s) else { return s }
        return display.string(from: d)
    }

    static func dayTitle(_ s: String) -> String {
        guard let d = parse(s) else { return s }
        return dayOnly.string(from: d)
    }

    /// Kunci hari lokal (yyyy-MM-dd) untuk mengelompokkan riwayat per hari.
    static func dayKey(_ s: String) -> String {
        guard let d = parse(s) else { return s }
        return ymd.string(from: d)
    }

    /// "2026-11-20" menjadi ("Jum", "20")
    static func chartDay(_ ymdString: String) -> (String, String) {
        guard let d = ymd.date(from: ymdString) else { return (ymdString, "") }
        let day = Calendar.current.component(.day, from: d)
        return (weekdayShort.string(from: d), String(day))
    }
}
