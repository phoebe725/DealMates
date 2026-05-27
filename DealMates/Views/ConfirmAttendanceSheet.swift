import SwiftUI

struct ConfirmAttendanceSheet: View {
    let plan: Plan
    @Binding var isPresented: Bool
    var onConfirmed: () -> Void

    @State private var attended: Set<String> = []
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @ObservedObject private var cache = UserCache.shared

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Mark who actually showed up")) {
                    ForEach(plan.memberIds, id: \.self) { uid in
                        Toggle(isOn: Binding(
                            get: { attended.contains(uid) },
                            set: { isOn in
                                if isOn { attended.insert(uid) }
                                else    { attended.remove(uid) }
                            }
                        )) {
                            HStack(spacing: 10) {
                                LiveAvatar(userId: uid, size: 32, fontSize: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cache.name(for: uid, fallback: "Diner"))
                                        .font(.subheadline)
                                    if uid == plan.creatorId {
                                        Text("Organiser")
                                            .font(.caption2)
                                            .foregroundColor(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Confirm Attendance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { submit() }
                        .bold()
                        .disabled(isSubmitting)
                }
            }
            .onAppear {
                attended = Set(plan.memberIds)
                Task { await cache.prefetch(ids: plan.memberIds) }
            }
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        Task {
            do {
                try await DatabaseService.shared.confirmAttendance(
                    planId: plan.id,
                    attendedUserIds: Array(attended)
                )
                onConfirmed()
                isPresented = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}
