import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @State private var showingAddTransaction = false

    private var openAccounts: [Account] {
        budgetStore.accounts.filter { !$0.closed }
    }

    private var onBudgetBalance: Int {
        openAccounts
            .filter { !$0.offBudget }
            .reduce(0) { $0 + $1.balance }
    }

    private var netWorth: Int {
        openAccounts.reduce(0) { $0 + $1.balance }
    }

    private var overspentCategories: [CategoryBudget] {
        budgetStore.currentBudgetMonth?.overspentCategories ?? []
    }

    private var recentTransactions: [Transaction] {
        budgetStore.transactions
            .filter { !$0.tombstone && $0.parentId == nil }
            .sorted {
                if $0.date != $1.date { return $0.date > $1.date }
                return ($0.sortOrder ?? 0) > ($1.sortOrder ?? 0)
            }
            .prefix(5)
            .map { $0 }
    }

    private var defaultAccountId: String? {
        let configuredId = budgetStore.defaultAccountId
        if let configuredId,
           openAccounts.contains(where: { $0.id == configuredId }) {
            return configuredId
        }
        return openAccounts.first?.id
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    overviewCard

                    if let month = budgetStore.currentBudgetMonth {
                        budgetCard(month)
                    }

                    if !overspentCategories.isEmpty {
                        needsAttentionCard
                    }

                    recentTransactionsCard
                }
                .padding(.horizontal)
                .padding(.bottom, 28)
            }
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddTransaction = true
                    } label: {
                        Label("Add Transaction", systemImage: "plus")
                    }
                    .disabled(defaultAccountId == nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Label("Add Transaction", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.top, 8)
                .background(.ultraThinMaterial)
                .disabled(defaultAccountId == nil)
            }
            .sheet(isPresented: $showingAddTransaction) {
                if let accountId = defaultAccountId {
                    AddTransactionView(accountId: accountId)
                        .environmentObject(budgetStore)
                } else {
                    ContentUnavailableView(
                        "No Accounts",
                        systemImage: "banknote",
                        description: Text("Add an account before creating a transaction")
                    )
                }
            }
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Money overview")
                .font(.headline)

            HStack(alignment: .firstTextBaseline) {
                metric(
                    title: "On budget",
                    value: formatted(onBudgetBalance),
                    systemImage: "wallet.bifold"
                )

                Divider()

                metric(
                    title: "Net worth",
                    value: formatted(netWorth),
                    systemImage: "chart.line.uptrend.xyaxis"
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func budgetCard(_ month: BudgetMonth) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("This month")
                    .font(.headline)
                Spacer()
                Text(month.month)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline) {
                metric(
                    title: "Available",
                    value: formatted(month.totalAvailable),
                    systemImage: "checkmark.circle"
                )

                Divider()

                metric(
                    title: "Spent",
                    value: formatted(month.totalSpent),
                    systemImage: "arrow.down.circle"
                )
            }

            if let toBudget = month.toBudget {
                HStack {
                    Label("Ready to assign", systemImage: "tray.full")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatted(toBudget))
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var needsAttentionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                Spacer()
                Text("\(overspentCategories.count)")
                    .font(.subheadline.weight(.semibold))
            }

            ForEach(overspentCategories.prefix(3)) { category in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.categoryName)
                            .font(.subheadline.weight(.medium))
                        Text(category.groupName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(formatted(category.available))
                        .font(.subheadline.weight(.semibold))
                }
            }

            if overspentCategories.count > 3 {
                Text("+ \(overspentCategories.count - 3) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var recentTransactionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent transactions")
                .font(.headline)

            if recentTransactions.isEmpty {
                ContentUnavailableView(
                    "No Transactions Yet",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Your most recent activity will appear here")
                )
                .frame(maxWidth: .infinity)
            } else {
                ForEach(recentTransactions) { transaction in
                    HStack(spacing: 12) {
                        Image(systemName: transactionDirectionIcon(for: transaction))
                            .frame(width: 28, height: 28)
                            .background(.thinMaterial, in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(transaction.payeeName?.isEmpty == false ? transaction.payeeName! : "Transaction")
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Text(transaction.categoryName ?? transaction.dateFormatted)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text(formatted(transaction.amount))
                            .font(.subheadline.monospacedDigit().weight(.semibold))
                    }

                    if transaction.id != recentTransactions.last?.id {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metric(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func transactionDirectionIcon(for transaction: Transaction) -> String {
        if budgetStore.hideBalances {
            return "arrow.left.arrow.right"
        }
        return transaction.amount < 0 ? "arrow.up.right" : "arrow.down.left"
    }

    private func formatted(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return "••••" }
        return CurrencyAmountFormat.string(
            cents: cents,
            currencyCode: budgetStore.currencyCode,
            narrowSymbol: budgetStore.useNarrowCurrencySymbol
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(BudgetStore.previewInstance())
}
