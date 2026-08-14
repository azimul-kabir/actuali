import Foundation

enum ReportChangeSummary {
    static func netWorth(data: NetWorthData, transactions: [Transaction]) -> String {
        guard let first = data.points.first, let last = data.points.last else {
            return "Not enough history to explain this change."
        }
        let delta = last.balanceCents - first.balanceCents
        let direction = delta > 0 ? "rose" : (delta < 0 ? "fell" : "was unchanged")
        guard delta != 0 else { return "Net worth was unchanged across this period." }
        let contributor = transactions.max { abs($0.amount) < abs($1.amount) }
        guard let contributor else { return "Net worth \(direction) across this period." }
        let name = contributor.payeeName ?? contributor.categoryName ?? "a transaction"
        let contribution = contributor.amount >= 0 ? "inflow" : "outflow"
        return "Net worth \(direction). The largest movement was an \(contribution) from \(name)."
    }

    static func spending(data: SpendingData, transactions: [Transaction]) -> String {
        let delta = data.currentSpentCents - data.comparisonCents
        let comparison: String
        if delta > 0 {
            comparison = "more than"
        } else if delta < 0 {
            comparison = "less than"
        } else {
            comparison = "the same as"
        }
        let outflows = transactions.filter { $0.amount < 0 }
        let largest = outflows.min(by: { $0.amount < $1.amount })
        guard let largest else { return "Spending is \(comparison) the comparison period." }
        let name = largest.categoryName ?? largest.payeeName ?? "Uncategorized"
        return "Spending is \(comparison) the comparison period. \(name) is the largest outflow."
    }
}
