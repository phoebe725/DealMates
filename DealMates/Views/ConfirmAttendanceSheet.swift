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
            ZStack {
                Color.pinCream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        header

                        VStack(spacing: 0) {
                            ForEach(plan.memberIds, id: \.self) { uid in
                                row(uid: uid)
                                if uid != plan.memberIds.last {
                                    Divider().background(Color.pinFog).padding(.leading, 58)
                                }
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.pinShell)
                        )

                        if let err = errorMessage {
                            errorBanner(err)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Confirm attendance")
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") { submit() }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinClay)
                        .disabled(isSubmitting)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                attended = Set(plan.memberIds)
                Task { await cache.prefetch(ids: plan.memberIds) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Who actually showed up?")
                .font(.pinBody(16, weight: .medium))
                .foregroundStyle(Color.pinInk)
            Text("Tap to toggle each puffin's attendance. We use this to keep credit scores honest.")
                .font(.pinSubtitle(13))
                .foregroundStyle(Color.pinInkMuted)
        }
        .padding(.top, 4)
    }

    private func row(uid: String) -> some View {
        let isAttended = attended.contains(uid)
        let isOrganiser = uid == plan.creatorId
        return Button {
            if isAttended { attended.remove(uid) } else { attended.insert(uid) }
        } label: {
            HStack(spacing: 12) {
                LiveAvatar(userId: uid, size: 36, fontSize: 14)
                VStack(alignment: .leading, spacing: 2) {
                    Text(cache.name(for: uid, fallback: AppLocalization.string("Diner")))
                        .font(.pinBody(14))
                        .foregroundStyle(Color.pinInk)
                    if isOrganiser {
                        Text("Organiser")
                            .font(.pinSubtitle(11))
                            .foregroundStyle(Color.pinClayDeep)
                    }
                }
                Spacer()
                Image(systemName: isAttended ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isAttended ? Color.pinClay : Color.pinInkMuted.opacity(0.4))
            }
            .padding(14)
        }
        .buttonStyle(.plain)
    }

    private func errorBanner(_ msg: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(Color.pinClayDeep)
            Text(msg)
                .font(.pinBody(13))
                .foregroundStyle(Color.pinInk)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.pinClay.opacity(0.12))
        )
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
