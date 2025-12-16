import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isFetchingDetailID: String?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
                .navigationBarTitleDisplayMode(.inline)
                .background(AppColors.background.ignoresSafeArea())
        }
        .task {
            vm.loadHistory()
        }
        // Show the system grabber and allow interactive drag to dismiss
        .presentationDragIndicator(.visible)
        // Optional: pick detents if you like the bottom-sheet feel; remove if you want full-screen
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(false) // ensure drag-to-dismiss is enabled
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoadingHistory {
            VStack(spacing: 16) {
                ProgressView()
                Text("Loading history…")
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let err = vm.historyError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 28))
                    .foregroundColor(.yellow)
                Text(err)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppColors.textSecondary)
                Button {
                    HapticManager.shared.selection()
                    vm.loadHistory()
                } label: {
                    Text("Retry")
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.surfaceStrong)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.historyItems.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 40))
                    .foregroundColor(AppColors.textSecondary)
                Text("No history yet")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text("Your recent searches will appear here.")
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(vm.historyItems, id: \.search_id) { item in
                    Button {
                        HapticManager.shared.selection()
                        fetchDetailAndApply(item)
                    } label: {
                        HStack(alignment: .center, spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.textSecondary)
                                .frame(width: 24, height: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.query)
                                    .foregroundColor(AppColors.textPrimary)
                                    .font(.system(size: 16, weight: .semibold))
                                    .lineLimit(1)
                                Text(format(date: item.timestamp))
                                    .foregroundColor(AppColors.textSecondary)
                                    .font(.system(size: 13))
                            }

                            Spacer()

                            if isFetchingDetailID == item.search_id {
                                ProgressView()
                            } else {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(AppColors.background)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
        }
    }

    private func fetchDetailAndApply(_ item: HistoryItem) {
        guard isFetchingDetailID == nil else { return }
        isFetchingDetailID = item.search_id

        Task {
            do {
                let response = try await vm.fetchHistoryDetail(for: item.search_id)
                vm.applyHistoryResult(response)
                dismiss()
            } catch {
                HapticManager.shared.notify(.error)
            }
            isFetchingDetailID = nil
        }
    }

    private func format(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    HistoryView()
        .environmentObject(HomeViewModel.makeDefault())
}
