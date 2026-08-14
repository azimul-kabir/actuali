import Foundation
import Testing
@testable import Actuali

struct ReportChangeSummaryTests {
    private func transaction(_ amount: Int, payee: String, category: String? = nil) -> Transaction {
        Transaction(
            id: UUID().uuidString, accountId: "account", date: 20260810,
            amount: amount, payeeId: nil, payeeName: payee,
            categoryId: nil, categoryName: category, notes: nil,
            cleared: true, reconciled: false, transferId: nil,
            isParent: false, parentId: nil, tombstone: false,
            sortOrder: nil, importedPayee: nil
        )
    }

    @Test func netWorthExplainsDirectionAndLargestMovement() {
        let data = NetWorthData(points: [
            .init(date: Date(timeIntervalSince1970: 0), balanceCents: 10_000),
            .init(date: Date(timeIntervalSince1970: 86_400), balanceCents: 15_000),
        ])
        let summary = ReportChangeSummary.netWorth(
            data: data,
            transactions: [transaction(8_000, payee: "Employer"), transaction(-3_000, payee: "Rent")]
        )
        #expect(summary.contains("rose"))
        #expect(summary.contains("Employer"))
    }

    @Test func spendingExplainsComparisonAndLargestOutflow() {
        let summary = ReportChangeSummary.spending(
            data: .init(currentSpentCents: 12_000, comparisonCents: 9_000),
            transactions: [
                transaction(-7_000, payee: "Market", category: "Groceries"),
                transaction(-2_000, payee: "Cafe", category: "Dining"),
            ]
        )
        #expect(summary.contains("more"))
        #expect(summary.contains("Groceries"))
    }
}
