import Testing
@testable import Actuali

struct StartTabTests {

    @Test func tabTagsMatchMainTabViewOrder() {
        #expect(StartTab.home.tabTag == 0)
        #expect(StartTab.accounts.tabTag == 1)
        #expect(StartTab.budget.tabTag == 2)
        #expect(StartTab.reports.tabTag == 3)
    }

    @Test func resolvesDefaultWhenUnset() {
        #expect(StartTab.resolved(from: nil) == .home)
    }

    @Test func resolvesDefaultForUnknownValue() {
        #expect(StartTab.resolved(from: "settings") == .home)
        #expect(StartTab.resolved(from: "") == .home)
    }

    @Test func resolvesLegacyAddTransactionToHome() {
        #expect(StartTab.resolved(from: "addTransaction") == .home)
    }

    @Test func resolvesPersistedRawValues() {
        for tab in StartTab.allCases {
            #expect(StartTab.resolved(from: tab.rawValue) == tab)
        }
    }
}
