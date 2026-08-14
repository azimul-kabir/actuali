import Foundation
import Testing
@testable import Actuali

struct BudgetMonthOverspentCountTests {

    private func makeCategory(id: String, available: Int, carryover: Int = 0) -> CategoryBudget {
        CategoryBudget(
            month: "2026-07",
            categoryId: id,
            categoryName: "Category \(id)",
            groupId: "g1",
            groupName: "Everyday",
            groupSortOrder: 0,
            categorySortOrder: 0,
            budgeted: 10000,
            spent: 10000 - available,
            available: available,
            carryover: carryover
        )
    }

    private func makeMonth(availables: [Int]) -> BudgetMonth {
        BudgetMonth(
            month: "2026-07",
            categoryBudgets: availables.enumerated().map { makeCategory(id: "cat\($0.offset)", available: $0.element) }
        )
    }

    @Test func emptyMonthHasNoOverspentCategories() {
        #expect(makeMonth(availables: []).overspentCount == 0)
    }

    @Test func healthyCategoriesDoNotCount() {
        #expect(makeMonth(availables: [5000, 0, 12000]).overspentCount == 0)
    }

    @Test func onlyNegativeAvailableCounts() {
        #expect(makeMonth(availables: [5000, -200, 0, -1]).overspentCount == 2)
    }

    @Test func exactlyZeroAvailableIsNotOverspent() {
        #expect(makeMonth(availables: [0]).overspentCount == 0)
    }

    // MARK: - overspentCategories (the badge's explanation, GH #138)

    @Test func overspentCategoriesListsOnlyTheOnesInTheRed() {
        let month = makeMonth(availables: [5000, -200, 0, -1])
        #expect(month.overspentCategories.map(\.available) == [-200, -1])
    }

    @Test func overspentCategoriesOrdersWorstFirst() {
        let month = makeMonth(availables: [-1, -5000, 300, -200])
        #expect(month.overspentCategories.map(\.available) == [-5000, -200, -1])
    }

    @Test func overspentCategoriesIsEmptyWhenNothingIsOverspent() {
        #expect(makeMonth(availables: [5000, 0]).overspentCategories.isEmpty)
    }

    // MARK: - rolledOverOverspending

    @Test func negativeCarryoverIsRolledOverOverspending() {
        let category = makeCategory(id: "c", available: -1500, carryover: -1000)
        #expect(category.rolledOverOverspending == -1000)
    }

    @Test func positiveCarryoverIsNotRolledOverOverspending() {
        let category = makeCategory(id: "c", available: -500, carryover: 2000)
        #expect(category.rolledOverOverspending == 0)
    }

    @Test func zeroCarryoverHasNoRolledOverOverspending() {
        let category = makeCategory(id: "c", available: -500)
        #expect(category.rolledOverOverspending == 0)
    }

    // MARK: - budget method summaries

    @Test func nilToBudgetIdentifiesTrackingBudget() {
        #expect(makeMonth(availables: []).isTrackingBudget)
    }

    @Test func toBudgetIdentifiesEnvelopeBudget() {
        var month = makeMonth(availables: [])
        month.toBudget = 0
        #expect(!month.isTrackingBudget)
    }

    @Test func trackingPlannedResultUsesBudgetedIncomeAndExpenses() {
        var month = makeMonth(availables: [4_000, 2_000])
        month.categoryBudgets[0].budgeted = 30_000
        month.categoryBudgets[1].budgeted = 20_000
        month.incomeCategories = [
            IncomeCategory(
                month: "2026-07",
                categoryId: "income",
                categoryName: "Salary",
                groupName: "Income",
                sortOrder: 0,
                budgeted: 75_000,
                received: 70_000
            )
        ]

        #expect(month.totalBudgetedIncome == 75_000)
        #expect(month.plannedResult == 25_000)
    }
}
