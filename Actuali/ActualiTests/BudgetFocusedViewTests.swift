import Testing
@testable import Actuali

struct BudgetFocusedViewTests {
    private func category(
        budgeted: Int = 0,
        spent: Int = 0,
        available: Int = 0,
        carryover: Int = 0
    ) -> CategoryBudget {
        CategoryBudget(
            month: "2026-08",
            categoryId: "category",
            categoryName: "Category",
            groupId: "group",
            groupName: "Group",
            groupSortOrder: 0,
            categorySortOrder: 0,
            budgeted: budgeted,
            spent: spent,
            available: available,
            carryover: carryover
        )
    }

    @Test func allIncludesEveryCategory() {
        #expect(BudgetFocusedView.all.includes(category()))
        #expect(BudgetFocusedView.all.includes(category(available: -100)))
    }

    @Test func notFundedUsesActualUnassignedState() {
        #expect(BudgetFocusedView.notFunded.includes(category()))
        #expect(!BudgetFocusedView.notFunded.includes(category(budgeted: 100, available: 100)))
        #expect(!BudgetFocusedView.notFunded.includes(category(spent: -100, available: -100)))
    }

    @Test func overspentUsesNegativeAvailable() {
        #expect(BudgetFocusedView.overspent.includes(category(available: -1)))
        #expect(!BudgetFocusedView.overspent.includes(category(available: 0)))
    }

    @Test func availableRequiresSpendableEnvelopeBalance() {
        #expect(BudgetFocusedView.available.includes(category(available: 1)))
        #expect(!BudgetFocusedView.available.includes(category(available: 0)))
        #expect(!BudgetFocusedView.available.includes(category(available: -1)))
    }

    @Test func activityIncludesInflowsAndOutflows() {
        #expect(BudgetFocusedView.activity.includes(category(spent: -100)))
        #expect(BudgetFocusedView.activity.includes(category(spent: 100)))
        #expect(!BudgetFocusedView.activity.includes(category(spent: 0)))
    }

    @Test func rawValuesRoundTripForPersistence() {
        for view in BudgetFocusedView.allCases {
            #expect(BudgetFocusedView(rawValue: view.rawValue) == view)
        }
    }
}
