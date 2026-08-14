import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = initialTab()
    @StateObject private var notificationRouter = NotificationRouter.shared
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.isWideLayout) private var isWideLayout

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    private static func initialTab() -> Int {
        #if DEBUG
        if let idx = CommandLine.arguments.firstIndex(of: "-initialTab"),
           idx + 1 < CommandLine.arguments.count,
           let tab = Int(CommandLine.arguments[idx + 1]) {
            return tab
        }
        #endif
        return StartTab.persisted.tabTag
    }

    private var overspentCount: Int {
        budgetStore.overspentBadgeCount
    }

    /// The numeric tab badge isn't surfaced to accessibility on its own, so
    /// mirror it as a spoken value on the tab label.
    private var overspentBadgeValue: String {
        switch overspentCount {
        case 0: ""
        case 1: "1 overspent category"
        default: "\(overspentCount) overspent categories"
        }
    }

    var body: some View {
        Group {
            // A wide iPad window (never iPhone) offers the sidebar as an
            // alternative to the floating tab bar. Gated on width, not just on
            // regular size class: in an 11-inch portrait window the sidebar
            // has no room to sit beside the content, so the toggle only ever
            // swaps the tab bar for a drawer over the top of it. Narrower
            // windows — and every phone — keep the plain tab bar.
            if horizontalSizeClass == .regular, isWideLayout {
                tabs.tabViewStyle(.sidebarAdaptable)
            } else {
                tabs
            }
        }
        .onChange(of: notificationRouter.pendingAllAccountsNavigation) { _, pending in
            if pending { selectedTab = 1 }
        }
        // A save from an add-transaction sheet routes to the account's
        // transaction list, which lives on the Accounts tab.
        .onChange(of: notificationRouter.pendingAccountNavigation) { _, accountId in
            if accountId != nil { selectedTab = 1 }
        }
        .onChange(of: notificationRouter.pendingBudgetNavigation) { _, pending in
            guard pending else { return }
            selectedTab = 2
            notificationRouter.pendingBudgetNavigation = false
        }
    }

    /// The `Tab` value API rather than `tabItem`: `sidebarAdaptable` above only
    /// takes effect for tabs declared this way. Renders identically to the
    /// `tabItem` form in compact width.
    private var tabs: some View {
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                HomeView()
            } label: {
                Label("Home", systemImage: "house.fill")
            }

            Tab(value: 1) {
                AccountsListView()
            } label: {
                Label("Accounts", systemImage: "banknote")
            }

            Tab(value: 2) {
                BudgetView()
            } label: {
                Label("Budget", systemImage: "wallet.bifold")
            }
            .badge(overspentCount)
            // On the tab, not its label: under the Tab API the tab's own
            // modifiers are what reach the tab bar item. (Neither placement
            // surfaces the value to XCUITest on iOS 26 — BudgetTabBadgeUITests
            // fails on main for that reason, unrelated to this.)
            .accessibilityValue(Text(overspentBadgeValue))

            Tab(value: 3) {
                ReportsTabView()
            } label: {
                Label("Reports", systemImage: "chart.bar.xaxis")
            }

            Tab(value: 4) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gear")
            }

            Tab(value: 5, role: .search) {
                GlobalSearchView { selectedTab = $0 }
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(BudgetStore.previewInstance())
}
