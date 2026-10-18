import Foundation

/// Spaced review of missed exercises (SPEC §18.6): a miss is due tomorrow; right in review pushes it to
/// +3 days, then +7, then it is done; wrong sends it back to tomorrow.
public struct ReviewItem: Hashable, Codable, Sendable {
  public var exercise: ExerciseID
  public var due: LocalDay
  /// 0 = due +1 day next, 1 = +3, 2 = +7 (the last step).
  public var step: Int

  public init(exercise: ExerciseID, due: LocalDay, step: Int = 0) {
    self.exercise = exercise
    self.due = due
    self.step = step
  }
}

public struct ReviewQueue: Hashable, Codable, Sendable {
  public static let intervals = [1, 3, 7]
  public static let maxItems = 200
  public static let sessionLimit = 10

  public var items: [ReviewItem] = []

  public init(items: [ReviewItem] = []) { self.items = items }

  /// A wrong answer: the exercise is due again tomorrow.
  public mutating func recordMiss(_ exercise: ExerciseID, today: LocalDay) {
    items.removeAll { $0.exercise == exercise }
    items.append(ReviewItem(exercise: exercise, due: today.adding(days: Self.intervals[0]), step: 0))
    if items.count > Self.maxItems { items.removeFirst(items.count - Self.maxItems) }
  }

  /// An answer in a review session.
  public mutating func recordReview(_ exercise: ExerciseID, correct: Bool, today: LocalDay) {
    guard let index = items.firstIndex(where: { $0.exercise == exercise }) else {
      if !correct { recordMiss(exercise, today: today) }
      return
    }
    if !correct {
      items[index].step = 0
      items[index].due = today.adding(days: Self.intervals[0])
      return
    }
    let next = items[index].step + 1
    if next >= Self.intervals.count {
      items.remove(at: index)
    } else {
      items[index].step = next
      items[index].due = today.adding(days: Self.intervals[next])
    }
  }

  /// The items due on or before `today`, most overdue first.
  public func due(today: LocalDay, limit: Int = ReviewQueue.sessionLimit) -> [ReviewItem] {
    let ready = items.enumerated().filter { $0.element.due <= today }
    return ready.sorted { a, b in
      a.element.due != b.element.due ? a.element.due < b.element.due : a.offset < b.offset
    }.prefix(limit).map(\.element)
  }

  public func dueCount(today: LocalDay) -> Int { items.filter { $0.due <= today }.count }
}
