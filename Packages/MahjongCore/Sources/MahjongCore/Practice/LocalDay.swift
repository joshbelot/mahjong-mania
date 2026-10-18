import Foundation

/// A calendar day as the user lives it (year, month, day), independent of time zones and daylight
/// saving. A `Date` becomes a `LocalDay` once, at the edge, with the user's calendar; everything after that
/// is whole-day arithmetic, so a 23- or 25-hour day or a changed time zone cannot skew a streak.
public struct LocalDay: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
  /// Days since 1970-01-01 in the proleptic Gregorian calendar.
  public let number: Int

  public init(number: Int) { self.number = number }

  public init(year: Int, month: Int, day: Int) {
    var y = year
    if month <= 2 { y -= 1 }
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    self.number = era * 146_097 + doe - 719_468
  }

  /// The calendar day `date` falls on in `calendar` (its time zone decides).
  public init(_ date: Date, calendar: Calendar = .current) {
    let c = calendar.dateComponents([.year, .month, .day], from: date)
    self.init(year: c.year ?? 1970, month: c.month ?? 1, day: c.day ?? 1)
  }

  public var ymd: (year: Int, month: Int, day: Int) {
    let z = number + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36_524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp + (mp < 10 ? 3 : -9)
    let y = yoe + era * 400 + (m <= 2 ? 1 : 0)
    return (y, m, d)
  }

  /// 1 = Monday … 7 = Sunday.
  public var isoWeekday: Int { (((number % 7) + 7 + 3) % 7) + 1 }

  public func adding(days: Int) -> LocalDay { LocalDay(number: number + days) }

  public func days(since other: LocalDay) -> Int { number - other.number }

  public static func < (a: LocalDay, b: LocalDay) -> Bool { a.number < b.number }

  /// "2026-10-17"
  public var description: String {
    let c = ymd
    return String(format: "%04d-%02d-%02d", c.year, c.month, c.day)
  }

  public init?(_ text: String) {
    let parts = text.split(separator: "-").compactMap { Int($0) }
    guard parts.count == 3, (1...12).contains(parts[1]), (1...31).contains(parts[2]) else { return nil }
    self.init(year: parts[0], month: parts[1], day: parts[2])
  }

  public init(from decoder: Decoder) throws {
    let value = try decoder.singleValueContainer().decode(String.self)
    guard let day = LocalDay(value) else {
      throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "bad day \(value)"))
    }
    self = day
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(description)
  }
}
