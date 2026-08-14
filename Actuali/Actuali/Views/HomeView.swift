import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @StateObject private var notificationRouter = NotificationRouter.shared
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
                .padding(.bottom, 96)
            }
            .navigationTitle("Home")
            .overlay(alignment: .bottomTrailing) {
                Button {
                    showingAddTransaction = true
                } label: {
                    Label("Add Transaction", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(width: 200)
                        .padding(.vertical, 13)
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 12)
                .padding(.trailing, 16)
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

            HStack(alignment: .top, spacing: 16) {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("This month")
                    .font(.headline)
                Spacer()
                Text(formattedMonth(month.month))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let toBudget = month.toBudget {
                Button {
                    notificationRouter.pendingBudgetNavigation = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Ready to assign", systemImage: "tray.full")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(formatted(toBudget))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(.primary)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the Budget tab to assign money")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Planned result", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(formatted(month.plannedResult))
                        .font(.title2.weight(.bold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack(spacing: 12) {
                if month.isTrackingBudget {
                    compactMetric(
                        title: "Actual income",
                        value: formatted(month.totalIncome),
                        systemImage: "arrow.down.circle"
                    )
                } else {
                    compactMetric(
                        title: "Available",
                        value: formatted(month.totalAvailable),
                        systemImage: "checkmark.circle"
                    )
                }

                compactMetric(
                    title: month.isTrackingBudget ? "Actual expenses" : "Spent",
                    value: formattedSpent(month.totalSpent),
                    systemImage: "arrow.down.circle"
                )
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var needsAttentionCard: some View {
        NavigationLink {
            OverspentCategoriesView()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(
                        budgetStore.currentBudgetMonth?.isTrackingBudget == true
                            ? "Review over budget"
                            : "Cover overspending",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.headline)
                    Spacer()
                    Text("\(overspentCategories.count)")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.tertiary)
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
            .foregroundStyle(.primary)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows categories that need attention")
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

    private func compactMetric(title: String, value: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formattedMonth(_ value: String) -> String {
        let parts = value.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return value
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar.current.date(from: components) else {
            return value
        }

        return date.formatted(.dateTime.month(.wide).year())
    }

    private func transactionDirectionIcon(for transaction: Transaction) -> String {
        if budgetStore.hideBalances {
            return "arrow.left.arrow.right"
        }
        return transaction.amount < 0 ? "arrow.up.right" : "arrow.down.left"
    }

    private func formattedSpent(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return cents > 0
            ? "+\(budgetStore.formatCurrency(cents))"
            : budgetStore.formatCurrency(-cents)
    }

    private func formatted(_ cents: Int) -> String {
        budgetStore.displayBalance(cents)
    }
}

#Preview {
    HomeView()
        .environmentObject(BudgetStore.previewInstance())
}
