import Testing
@testable import Actuali

struct TransactionDateGroupTests {
    private func transaction(id: String, date: Int) -> Transaction {
        Transaction(
            id: id,
            accountId: "account",
            date: date,
            amount: -100,
            payeeId: nil,
            payeeName: nil,
            categoryId: nil,
            categoryName: nil,
            notes: nil,
            cleared: false,
            reconciled: false,
            transferId: nil,
            isParent: false,
            parentId: nil,
            tombstone: false,
            sortOrder: nil,
            importedPayee: nil
        )
    }

    @Test func groupsConsecutiveTransactionsWithoutChangingTheirOrder() {
        let transactions = [
            transaction(id: "newest", date: 20260814),
            transaction(id: "same-day", date: 20260814),
            transaction(id: "older", date: 20260813)
        ]

        let groups = TransactionDateGroup.grouped(transactions)

        #expect(groups.map(\.id) == [20260814, 20260813])
        #expect(groups[0].transactions.map(\.id) == ["newest", "same-day"])
        #expect(groups[1].transactions.map(\.id) == ["older"])
    }

    @Test func emptyTransactionListProducesNoSections() {
        #expect(TransactionDateGroup.grouped([]).isEmpty)
    }
}
