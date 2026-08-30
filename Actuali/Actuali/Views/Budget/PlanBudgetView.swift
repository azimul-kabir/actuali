import SwiftUI

/// A planning-focused third Budget layout. Clean and Detailed keep their
/// established views; this screen owns its density, disclosure state and
/// interactions while sharing only Actual's data and write services.
struct PlanBudgetView: View {
    private static let creditCardsCollapseID = "__plan_credit_cards__"

    @EnvironmentObject private var budgetStore: BudgetStore

    let budget: BudgetMonth
    let onEditAmount: (CategoryBudget) -> Void
    let onShowDetails: (CategoryBudget) -> Void
    let onMoveMoney: (CategoryBudget) -> Void
    let onShowTransactions: (CategoryBudget, String?) -> Void
    let onShowIncomeTransactions: (IncomeCategory, String?) -> Void

    @AppStorage("collapsedPlanBudgetGroups") private var collapsedStorage = ""

    private var collapsedGroups: Set<String> {
        Set(collapsedStorage.split(separator: ",").map(String.init))
    }

    private var groups: [PlanBudgetGroup] {
        let source = budgetStore.showHiddenCategories
            ? budget.allCategoryBudgets
            : budget.categoryBudgets
        let byGroup = Dictionary(grouping: source, by: \.groupId)
        return byGroup.compactMap { groupID, categories in
            guard let first = categories.first else { return nil }
            let visible = budgetStore.visibleCategoryBudgets(categories)
                .sorted { $0.categorySortOrder < $1.categorySortOrder }
            guard !visible.isEmpty else { return nil }
            return PlanBudgetGroup(
                id: groupID,
                name: first.groupName,
                sortOrder: first.groupSortOrder,
                categories: visible
            )
        }
        .sorted { $0.sortOrder < $1.sortOrder }
    }

    private var incomeCategories: [IncomeCategory] {
        let categories = budgetStore.showHiddenCategories
            ? budget.allIncomeCategories
            : budget.incomeCategories
        return categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var trackedCreditCards: [(account: Account, cycle: CreditCardCycle)] {
        budgetStore.accounts.compactMap { account in
            guard account.type == .credit,
                  !account.closed,
                  let cycle = budgetStore.activeCreditCardCycle(for: account.id)
            else { return nil }
            return (account, cycle)
        }
        .sorted { $0.account.sortOrder < $1.account.sortOrder }
    }

    var body: some View {
        List {
            Section {
                PlanBudgetSummary(budget: budget)
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
            }

            if !trackedCreditCards.isEmpty {
                let collapsed = collapsedGroups.contains(Self.creditCardsCollapseID)
                Section {
                    PlanCreditCardsHeader(
                        cards: trackedCreditCards.map(\.account),
                        isCollapsed: collapsed,
                        onToggle: { toggle(Self.creditCardsCollapseID) }
                    )
                    .listRowBackground(Color(.secondarySystemGroupedBackground))

                    if !collapsed {
                        ForEach(trackedCreditCards, id: \.account.id) { item in
                            NavigationLink {
                                AccountDetailView(account: item.account)
                            } label: {
                                PlanCreditCardRow(account: item.account, cycle: item.cycle)
                            }
                        }
                    }
                }
            }

            Section {
                PlanColumnHeader(isTracking: budget.isTrackingBudget)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 4, trailing: 16))
            }

            ForEach(groups) { group in
                let collapsed = collapsedGroups.contains(group.id)
                Section {
                    PlanGroupHeader(
                        group: group,
                        isCollapsed: collapsed,
                        isTracking: budget.isTrackingBudget,
                        onToggle: { toggle(group.id) }
                    )
                    .listRowBackground(Color(.secondarySystemGroupedBackground))
                    .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))

                    if !collapsed {
                        ForEach(group.categories) { category in
                            PlanCategoryRow(
                                category: category,
                                isTracking: budget.isTrackingBudget,
                                showsProgress: budgetStore.showPlanProgressBars,
                                onEditAmount: { onEditAmount(category) },
                                onShowDetails: { onShowDetails(category) },
                                onMoveMoney: { onMoveMoney(category) },
                                onShowTransactions: {
                                    onShowTransactions(category, category.month)
                                }
                            )
                        }
                    }
                }
            }

            if !incomeCategories.isEmpty {
                Section {
                    PlanIncomeHeader(
                        received: budget.totalIncome,
                        isCollapsed: collapsedGroups.contains(BudgetView.incomeGroupCollapseID),
                        onToggle: { toggle(BudgetView.incomeGroupCollapseID) }
                    )
                    .listRowBackground(Color(.tertiarySystemFill))

                    if !collapsedGroups.contains(BudgetView.incomeGroupCollapseID) {
                        ForEach(incomeCategories) { income in
                            Button {
                                onShowIncomeTransactions(income, income.month)
                            } label: {
                                HStack {
                                    Text(income.categoryName)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(planNumber(income.received))
                                        .foregroundStyle(income.received > 0 ? .green : .secondary)
                                        .monospacedDigit()
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(.custom(12))
        .environment(\.defaultMinListRowHeight, 34)
        .animation(AppAnimation.disclosure, value: collapsedStorage)
        .refreshable { await budgetStore.sync() }
    }

    private func toggle(_ id: String) {
        var collapsed = collapsedGroups
        if !collapsed.insert(id).inserted { collapsed.remove(id) }
        collapsedStorage = collapsed.sorted().joined(separator: ",")
    }

    private func planNumber(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

private struct PlanBudgetSummary: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let budget: BudgetMonth

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(budget.isTrackingBudget ? "Budgeted" : "Ready to Assign")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount(budget.isTrackingBudget ? budget.totalBudgeted : budget.toBudget ?? 0))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(summaryColor)
                    .monospacedDigit()
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(budget.isTrackingBudget ? "Balance" : "Available")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(amount(budget.totalAvailable))
                    .font(.headline)
                    .foregroundStyle(budget.totalAvailable < 0 ? .red : .primary)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryColor: Color {
        guard !budget.isTrackingBudget, let toBudget = budget.toBudget else { return .primary }
        return toBudget < 0 ? .red : .green
    }

    private func amount(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

private struct PlanCreditCardsHeader: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let cards: [Account]
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isCollapsed ? -90 : 0))
                Text("Credit Cards")
                    .font(.headline)
                Spacer()
                Text(amount(cards.reduce(0) { $0 + $1.balance }))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func amount(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

private struct PlanCreditCardRow: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let account: Account
    let cycle: CreditCardCycle

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(account.name)
                    .lineLimit(1)
                Spacer()
                Text(amount(account.balance))
                    .fontWeight(.semibold)
                    .foregroundStyle(account.balance < 0 ? .red : .primary)
                    .monospacedDigit()
            }
            HStack {
                Text("Statement day \(cycle.statementDay)")
                Spacer()
                Text(cycle.dueShortSummary())
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let available = budgetStore.availableCredit(for: account.id) {
                Text("Available credit \(amount(available))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func amount(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

struct PlanBudgetGroup: Identifiable {
    let id: String
    let name: String
    let sortOrder: Double
    let categories: [CategoryBudget]

    var totals: CategoryGroupTotals { CategoryGroupTotals(categories) }
}

private struct PlanColumnHeader: View {
    let isTracking: Bool

    var body: some View {
        HStack {
            Text("Category")
            Spacer()
            Text(isTracking ? "Budget" : "Assigned")
                .frame(width: 88, alignment: .trailing)
            Text(isTracking ? "Balance" : "Available")
                .frame(width: 88, alignment: .trailing)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }
}

private struct PlanGroupHeader: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let group: PlanBudgetGroup
    let isCollapsed: Bool
    let isTracking: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .foregroundStyle(.secondary)
                Text(group.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(number(group.totals.budgeted))
                    .frame(width: 84, alignment: .trailing)
                Text(number(group.totals.balance))
                    .foregroundStyle(group.totals.balance < 0 ? .red : .primary)
                    .frame(width: 84, alignment: .trailing)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(group.name), \(isCollapsed ? "collapsed" : "expanded")")
        .accessibilityHint("Shows or hides categories")
    }

    private func number(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

private struct PlanCategoryRow: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let category: CategoryBudget
    let isTracking: Bool
    let showsProgress: Bool
    let onEditAmount: () -> Void
    let onShowDetails: () -> Void
    let onMoveMoney: () -> Void
    let onShowTransactions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: showsProgress ? 7 : 2) {
            HStack(spacing: 6) {
                Button(action: onShowDetails) {
                    HStack(spacing: 7) {
                        CompactCategoryStatusDot(state: category.progressState)
                        Text(category.categoryName)
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: onEditAmount) {
                    Text(number(category.budgeted))
                        .monospacedDigit()
                        .frame(width: 88, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                .accessibilityLabel("Edit \(isTracking ? "budget" : "assigned")")

                Button(action: onMoveMoney) {
                    Text(number(category.available))
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(availableTint.opacity(0.18)))
                        .frame(width: 88, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .foregroundStyle(availableTint)
                .accessibilityLabel("Move money, available \(number(category.available))")
            }

            if showsProgress {
                if category.showsProgressBar {
                    CategoryProgressBar(
                        fraction: category.progressFraction,
                        state: category.progressState
                    )
                }
                Button(action: onShowTransactions) {
                    Text(progressText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, showsProgress ? 4 : 1)
        .opacity(category.isEffectivelyHidden ? 0.5 : 1)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            Button("Assign", systemImage: "pencil", action: onEditAmount)
                .tint(.accentColor)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button("Move", systemImage: "arrow.left.arrow.right", action: onMoveMoney)
                .tint(.blue)
        }
    }

    private var availableTint: Color {
        if category.available < 0 { return .red }
        if category.available == 0 { return .secondary }
        return .green
    }

    private var progressText: String {
        switch category.progressState {
        case .overspent:
            return "Overspent by \(number(abs(category.available)))"
        case .spent:
            return "Fully spent"
        case .unassigned:
            return isTracking ? "No budget set" : "No money assigned"
        case .funded:
            return isTracking ? "Budget set" : "Funded"
        case .spending:
            let verb = isTracking ? "Used" : "Spent"
            let capacity = abs(category.spent) + max(category.available, 0)
            return "\(category.progressState.statusText). \(verb) \(number(abs(category.spent))) of \(number(capacity))"
        }
    }

    private func number(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

private struct PlanIncomeHeader: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let received: Int
    let isCollapsed: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .foregroundStyle(.secondary)
                Text("Source of Fund")
                    .font(.headline)
                Spacer()
                Text("Received \(number(received))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func number(_ cents: Int) -> String {
        guard !budgetStore.hideBalances else { return BudgetStore.hiddenBalanceText }
        return BudgetColumn.text(cents, wholeUnits: budgetStore.hideDecimalPlaces)
    }
}

/// Plan-only category workspace. It exposes Actual-supported actions and
/// deliberately omits targets, reorder and YNAB credit-card semantics.
struct PlanCategoryDetailSheet: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    @Environment(\.dismiss) private var dismiss

    let category: CategoryBudget
    let onEditAmount: () -> Void
    let onMoveMoney: () -> Void
    let onShowActivity: () -> Void

    @State private var name: String
    @State private var note: EntityNote = .unsupported
    @State private var history: [CategoryBudget] = []
    @State private var editingNote = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        category: CategoryBudget,
        onEditAmount: @escaping () -> Void,
        onMoveMoney: @escaping () -> Void,
        onShowActivity: @escaping () -> Void
    ) {
        self.category = category
        self.onEditAmount = onEditAmount
        self.onMoveMoney = onMoveMoney
        self.onShowActivity = onShowActivity
        _name = State(initialValue: category.categoryName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("From previous months", value: amount(previousBalance))
                    Button(action: onEditAmount) {
                        LabeledContent(isTracking ? "Budgeted this month" : "Assigned this month") {
                            Text(amount(category.budgeted))
                        }
                    }
                    LabeledContent("Activity this month", value: amount(category.spent))
                    Button(action: onMoveMoney) {
                        LabeledContent(isTracking ? "Balance" : "Available") {
                            Text(amount(category.available))
                                .foregroundStyle(category.available < 0 ? .red : .green)
                        }
                    }
                }

                Section(isTracking ? "Quick Budget" : "Quick Assign") {
                    if suggestions.isEmpty {
                        Text("No suggestions available")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(suggestions) { suggestion in
                            Button {
                                Task { await apply(suggestion) }
                            } label: {
                                LabeledContent(title(suggestion.kind)) {
                                    Text(amount(suggestion.amount))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    Button("Move Money", systemImage: "arrow.left.arrow.right", action: onMoveMoney)
                }

                Section("Category") {
                    TextField("Category Name", text: $name)
                    if note.supported {
                        Button(note.isEmpty ? "Add Note" : "Edit Note", systemImage: "note.text") {
                            editingNote = true
                        }
                        if !note.isEmpty {
                            Text(NoteLinkText.attributed(note.text))
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Activity", systemImage: "list.bullet", action: onShowActivity)
                    Button(category.hidden ? "Show Category" : "Hide Category",
                           systemImage: category.hidden ? "eye" : "eye.slash") {
                        Task { await toggleHidden() }
                    }
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
            }
            .navigationTitle(category.categoryName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await saveName() } }
                        .disabled(isSaving || trimmedName.isEmpty)
                }
            }
            .task {
                async let fetchedNote = budgetStore.fetchNote(id: category.categoryId)
                async let fetchedHistory = budgetStore.budgetHistory(for: category)
                note = await fetchedNote
                history = await fetchedHistory
            }
            .sheet(isPresented: $editingNote, onDismiss: {
                Task { note = await budgetStore.fetchNote(id: category.categoryId) }
            }) {
                NoteEditorView(
                    noteId: category.categoryId,
                    title: category.categoryName,
                    note: note.text
                )
            }
        }
    }

    private var isTracking: Bool { budgetStore.currentBudgetMonth?.isTrackingBudget == true }
    private var previousBalance: Int { category.available - category.budgeted - category.spent }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var suggestions: [QuickAssignSuggestion] { category.quickAssignSuggestions(history: history) }

    private func amount(_ cents: Int) -> String { budgetStore.displayBalance(cents) }

    private func title(_ kind: QuickAssignSuggestion.Kind) -> String {
        switch kind {
        case .spentLastMonth: "Spent Last Month"
        case .averageSpent: "Average Spent"
        case .assignedLastMonth: isTracking ? "Budgeted Last Month" : "Assigned Last Month"
        case .resetAvailable: isTracking ? "Reset Balance to Zero" : "Reset Available to Zero"
        case .setToZero: isTracking ? "Set Budget to Zero" : "Set Assigned to Zero"
        }
    }

    private func apply(_ suggestion: QuickAssignSuggestion) async {
        isSaving = true
        do {
            try await budgetStore.setBudgetAmount(
                month: category.month,
                categoryId: category.categoryId,
                amountCents: suggestion.amount
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func saveName() async {
        guard trimmedName != category.categoryName else { dismiss(); return }
        isSaving = true
        do {
            try await budgetStore.renameCategory(
                id: category.categoryId,
                name: trimmedName,
                month: category.month
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isSaving = false
        }
    }

    private func toggleHidden() async {
        do {
            try await budgetStore.setCategoryHidden(
                id: category.categoryId,
                hidden: !category.hidden,
                month: category.month
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
