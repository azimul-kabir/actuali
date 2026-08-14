import SwiftUI

struct ReportTransactionsDestination: Identifiable, Hashable {
    let title: String
    let explanation: String
    let transactions: [Transaction]

    var id: String {
        "\(title)-\(transactions.count)-\(transactions.first?.id ?? "")-\(transactions.last?.id ?? "")"
    }
}

struct ReportTransactionsView: View {
    let destination: ReportTransactionsDestination
    @State private var searchText = ""

    private var filteredTransactions: [Transaction] {
        guard !searchText.isEmpty else { return destination.transactions }
        let matcher = TransactionSearchMatcher(searchText)
        return destination.transactions.filter { matcher.matches($0) }
    }

    var body: some View {
        List {
            Section("Why this changed") {
                Text(destination.explanation)
                    .foregroundStyle(.secondary)
            }
            Section("Transactions") {
                if filteredTransactions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ForEach(filteredTransactions) { transaction in
                        TransactionRow(transaction: transaction)
                    }
                }
            }
        }
        .navigationTitle(destination.title)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Search transactions")
    }
}
