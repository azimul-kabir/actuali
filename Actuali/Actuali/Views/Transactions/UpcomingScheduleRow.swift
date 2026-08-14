import SwiftUI

struct UpcomingScheduleRow: View {
    @EnvironmentObject private var budgetStore: BudgetStore
    let schedule: Schedule
    let showsAccount: Bool
    let isPosting: Bool
    let post: () async -> Void

    private var payeeName: String {
        if let id = schedule.payeeId,
           let payee = budgetStore.payees.first(where: { $0.id == id }) {
            return payee.name
        }
        if let name = schedule.name, !name.isEmpty { return name }
        return "Scheduled transaction"
    }

    private var detail: String {
        var parts: [String] = []
        if let id = schedule.categoryId {
            let category = budgetStore.categoryGroups
                .flatMap(\.categories)
                .first(where: { $0.id == id })?.name
            if let category { parts.append(category) }
        }
        if showsAccount,
           let account = budgetStore.accounts.first(where: { $0.id == schedule.accountId }) {
            parts.append(account.name)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(payeeName).lineLimit(1)
                Text(ScheduleDateLabel.text(for: schedule.nextDate))
                    .font(.caption)
                    .foregroundStyle(schedule.nextDate < .today() ? Color.red : Color.secondary)
                if !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                Text(budgetStore.displayBalance(schedule.amount?.postAmount ?? 0))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button {
                    Task { await post() }
                } label: {
                    if isPosting {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Post Now").font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.borderless)
                .disabled(isPosting)
            }
        }
        .accessibilityElement(children: .contain)
    }
}

enum ScheduleDateLabel {
    static func text(for date: DayDate, today: DayDate = .today()) -> String {
        if date == today { return "Today" }
        if date == today.adding(days: 1) { return "Tomorrow" }
        if date < today {
            let days = distance(from: date, to: today)
            return days == 1 ? "1 day overdue" : "\(days) days overdue"
        }
        let days = distance(from: today, to: date)
        if days <= 7 { return "In \(days) days" }
        return Transaction.date(fromYYYYMMDD: date.yyyymmdd)
            .formatted(date: .abbreviated, time: .omitted)
    }

    private static func distance(from start: DayDate, to end: DayDate) -> Int {
        var date = start
        var days = 0
        while date < end {
            date = date.adding(days: 1)
            days += 1
        }
        return days
    }
}
