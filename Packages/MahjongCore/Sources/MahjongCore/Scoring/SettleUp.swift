import Foundation

extension Scoring {
  /// Greedy settle-up: repeatedly match the largest debtor with the largest creditor.
  /// Output is sorted by amount descending (ties by ids) and has at most `players - 1` transfers.
  public static func settleUp(_ cents: [String: Int]) -> [Transfer] {
    var debtors = cents.filter { $0.value < 0 }.map { (id: $0.key, amount: -$0.value) }
    var creditors = cents.filter { $0.value > 0 }.map { (id: $0.key, amount: $0.value) }
    var transfers: [Transfer] = []

    func largest(_ list: [(id: String, amount: Int)]) -> Int? {
      var best: Int?
      for index in list.indices where list[index].amount > 0 {
        if let current = best {
          let a = list[index]
          let b = list[current]
          if a.amount > b.amount || (a.amount == b.amount && a.id < b.id) { best = index }
        } else {
          best = index
        }
      }
      return best
    }

    while let d = largest(debtors), let c = largest(creditors) {
      let moved = min(debtors[d].amount, creditors[c].amount)
      transfers.append(Transfer(fromID: debtors[d].id, toID: creditors[c].id, cents: moved))
      debtors[d].amount -= moved
      creditors[c].amount -= moved
    }

    return transfers.sorted {
      if $0.cents != $1.cents { return $0.cents > $1.cents }
      if $0.fromID != $1.fromID { return $0.fromID < $1.fromID }
      return $0.toID < $1.toID
    }
  }
}
