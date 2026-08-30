import Foundation
import Testing
@testable import Actuali

/// The Budget tab's layout preference (actios-96wa) must default to the
/// clean App Store-screenshot look and persist like the other display
/// settings.
@MainActor
struct BudgetStoreDisplayStyleTests {

    @Test func defaultsToClean() {
        let store = BudgetStore.previewInstance()
        #expect(store.budgetDisplayStyle == .clean)
    }

    @Test func selectionPersistsToUserDefaults() {
        let store = BudgetStore.previewInstance()
        store.budgetDisplayStyle = .plan
        #expect(UserDefaults.standard.string(forKey: "budgetDisplayStyle") == "plan")
        store.budgetDisplayStyle = .clean
        #expect(UserDefaults.standard.string(forKey: "budgetDisplayStyle") == "clean")
    }

    @Test func planProgressPreferenceIsIndependent() {
        let store = BudgetStore.previewInstance()
        store.showBudgetProgressBars = true
        store.showPlanProgressBars = false

        store.showPlanProgressBars = true

        #expect(store.showPlanProgressBars)
        #expect(store.showBudgetProgressBars)
        #expect(UserDefaults.standard.bool(forKey: "showPlanProgressBars"))
    }

    /// Raw values round-trip, and unknown raw values (from a future build)
    /// decode to nil so init falls back to the default rather than crashing.
    @Test func rawValueRoundTrip() {
        for style in BudgetDisplayStyle.allCases {
            #expect(BudgetDisplayStyle(rawValue: style.rawValue) == style)
        }
        #expect(BudgetDisplayStyle(rawValue: "table-3000") == nil)
    }
}
