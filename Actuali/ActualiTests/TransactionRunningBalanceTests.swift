import Testing
@testable import Actuali

struct TransactionRunningBalanceTests {
    private func transaction(id: String, amount: Int) -> Transaction {
        Transaction(
            id: id,
            accountId: "account",
            date: 20260814,
            amount: amount,
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

    @Test func calculatesBalancesAfterEachNewestFirstTransaction() {
        let balances = TransactionRunningBalance.values(
            currentBalance: 8_500,
            transactions: [
                transaction(id: "newest-expense", amount: -1_500),
                transaction(id: "income", amount: 5_000),
                transaction(id: "older-expense", amount: -2_000)
            ]
        )

        #expect(balances["newest-expense"] == 8_500)
        #expect(balances["income"] == 10_000)
        #expect(balances["older-expense"] == 5_000)
    }

    @Test func emptyRegisterProducesNoBalances() {
        #expect(TransactionRunningBalance.values(currentBalance: 1_000, transactions: []).isEmpty)
    }
}
