import SwiftUI

struct GlobalSearchView: View {
    private struct SearchCommand: Identifiable {
        let title: String
        let keywords: String
        let icon: String
        let tab: Int

        var id: String { title }
    }

    @EnvironmentObject private var budgetStore: BudgetStore
    let onSelectTab: (Int) -> Void

    @State private var query = ""
    @State private var transactions: [Transaction] = []

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var accounts: [Account] {
        guard !trimmedQuery.isEmpty else { return [] }
        return budgetStore.accounts.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var categories: [Category] {
        guard !trimmedQuery.isEmpty else { return [] }
        return budgetStore.categoryGroups.flatMap(\.categories).filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var payees: [Payee] {
        guard !trimmedQuery.isEmpty else { return [] }
        return budgetStore.payees.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var matchingTransactions: [Transaction] {
        guard !trimmedQuery.isEmpty else { return [] }
        let matcher = TransactionSearchMatcher(trimmedQuery)
        return Array(transactions.filter { matcher.matches($0) }.prefix(20))
    }

    private var commands: [SearchCommand] {
        let all = [
            SearchCommand(title: "Open Accounts", keywords: "bank balances transactions", icon: "banknote", tab: 1),
            SearchCommand(title: "Open Budget", keywords: "categories assign envelope tracking", icon: "wallet.bifold", tab: 2),
            SearchCommand(title: "Open Reports", keywords: "net worth spending charts", icon: "chart.bar.xaxis", tab: 3),
            SearchCommand(title: "Open Settings", keywords: "preferences", icon: "gear", tab: 4),
            SearchCommand(title: "Currency Settings", keywords: "symbol format BDT taka", icon: "dollarsign.circle", tab: 4),
            SearchCommand(title: "Appearance Settings", keywords: "theme light dark", icon: "paintbrush", tab: 4),
            SearchCommand(title: "Notification Settings", keywords: "alerts reminders", icon: "bell", tab: 4),
            SearchCommand(title: "Scheduled Transactions", keywords: "schedule recurring upcoming", icon: "calendar", tab: 4),
            SearchCommand(title: "Privacy Settings", keywords: "hide balances security", icon: "lock", tab: 4)
        ]
        guard !trimmedQuery.isEmpty else { return Array(all.prefix(4)) }
        return all.filter {
            $0.title.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.keywords.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var hasResults: Bool {
        !commands.isEmpty || !accounts.isEmpty || !categories.isEmpty
            || !payees.isEmpty || !matchingTransactions.isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                if !commands.isEmpty {
                    Section("Commands") {
                        ForEach(commands) { command in
                            Button {
                                onSelectTab(command.tab)
                            } label: {
                                Label(command.title, systemImage: command.icon)
                            }
                        }
                    }
                }

                if !trimmedQuery.isEmpty {
                    if !accounts.isEmpty {
                        Section("Accounts") {
                            ForEach(accounts.prefix(8)) { account in
                                NavigationLink {
                                    AccountDetailView(account: account)
                                } label: {
                                    Label(account.name, systemImage: "banknote")
                                }
                            }
                        }
                    }

                    if !categories.isEmpty {
                        Section("Categories") {
                            ForEach(categories.prefix(8)) { category in
                                NavigationLink {
                                    CategoryTransactionsView(destination: .init(
                                        categoryId: category.id,
                                        categoryName: category.name,
                                        month: nil
                                    ))
                                } label: {
                                    Label(category.name, systemImage: "folder")
                                }
                            }
                        }
                    }

                    if !payees.isEmpty {
                        Section("Payees") {
                            ForEach(payees.prefix(8)) { payee in
                                let matches = transactions.filter { $0.payeeId == payee.id }
                                NavigationLink {
                                    ReportTransactionsView(destination: .init(
                                        title: payee.name,
                                        explanation: "Transactions for this payee.",
                                        transactions: matches
                                    ))
                                } label: {
                                    Label(payee.name, systemImage: "person.crop.circle")
                                }
                            }
                        }
                    }

                    if !matchingTransactions.isEmpty {
                        Section("Transactions") {
                            ForEach(matchingTransactions) { transaction in
                                TransactionRow(transaction: transaction)
                            }
                        }
                    }

                    if !hasResults {
                        ContentUnavailableView.search(text: trimmedQuery)
                            .listRowBackground(Color.clear)
                    }
                }
            }
            .navigationTitle("Search")
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Accounts, categories, payees, transactions"
            )
            .task(id: budgetStore.dataVersion) {
                guard let database = budgetStore.databaseForLogger else {
                    transactions = []
                    return
                }
                transactions = (try? await database.fetchTransactionsForReports()) ?? []
            }
        }
        .initialSyncBanner()
    }

}
