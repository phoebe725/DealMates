import SwiftUI

struct CreatePlanView: View {
    let restaurant: Restaurant
    let existingPlan: Plan?
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var timeType: PlanTimeType = .asap
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var flexDay: FlexDay = .weekday
    @State private var flexMeal: FlexMeal = .lunch
    @State private var neededPeople = 3
    @State private var currentPeople = 1
    @State private var genderPreference: GenderPreference = .any
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let minPeople = 1
    private let minNeeded = 2   // a plan needs ≥2 people to be a real group
    private let maxPeople = 10

    init(restaurant: Restaurant, planVM: PlanViewModel, existingPlan: Plan? = nil) {
        self.restaurant = restaurant
        self.planVM = planVM
        self.existingPlan = existingPlan
    }

    private var isEditing: Bool { existingPlan != nil }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                if authViewModel.isSignedIn {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header

                            section("When") { timeSection }
                            section("Group size") { sizeSection }
                            section("Open to") { preferenceSection }
                            section("Notes (optional)") { notesSection }

                            if let err = errorMessage { errorBanner(err) }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 96)
                    }
                } else {
                    guestGate
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
                if authViewModel.isSignedIn {
                    ToolbarItem(placement: .confirmationAction) {
                        if isSubmitting {
                            ProgressView().tint(Color.pinClay)
                        } else {
                            Button(isEditing ? "Save" : "Pin it") { submit() }
                                .font(.pinButton(15))
                                .foregroundStyle(Color.pinClay)
                        }
                    }
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { prefillIfEditing() }
        }
    }

    // MARK: - Guest gate (mirrors web — guests browse & join, but creating needs an account)

    private var guestGate: some View {
        VStack(spacing: 16) {
            Text("🍽️").font(.system(size: 52))
            Text("Create a free account to start a plan")
                .font(.pinHero(22, weight: .light))
                .foregroundStyle(Color.pinInk)
                .multilineTextAlignment(.center)
            Text("You can still join plans as a guest — no account needed for that.")
                .font(.pinSubtitle(14))
                .foregroundStyle(Color.pinInkMuted)
                .multilineTextAlignment(.center)
            NavigationLink {
                LoginView(startInSignUp: true)
            } label: {
                Text("Sign up or log in")
                    .font(.pinButton(16))
                    .foregroundStyle(Color.pinCream)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.pinClay, in: Capsule())
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            (
                Text(isEditing ? "Edit my " : "Pin a ")
                    .font(.pinHero(28, weight: .light))
                    .foregroundStyle(Color.pinInk)
                +
                Text(isEditing ? "pin." : "plan.")
                    .font(.pinAccent(38))
                    .foregroundStyle(Color.pinClayDeep)
            )
            .lineLimit(1)
            Text("At \(restaurant.displayName).")
                .font(.pinSubtitle(13))
                .foregroundStyle(Color.pinInkMuted)
        }
        .padding(.top, 4)
    }

    // MARK: - Section wrapper

    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PinSectionHeader(title: title)
            VStack(alignment: .leading, spacing: 14) {
                content()
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.pinShell)
            )
        }
    }

    // MARK: - Time

    private var timeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PinSegmentedPicker(
                options: [(value: PlanTimeType.asap, label: "ASAP"),
                          (value: PlanTimeType.scheduled, label: "Specific"),
                          (value: PlanTimeType.flexible, label: "Flexible")],
                selection: $timeType
            )

            switch timeType {
            case .asap:
                Text("Available now — others can join right away.")
                    .font(.pinSubtitle(13))
                    .foregroundStyle(Color.pinInkMuted)
            case .scheduled:
                DatePicker("Pick a time",
                           selection: $scheduledAt,
                           in: Date()...,
                           displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.compact)
                    .tint(Color.pinClay)
                    .font(.pinBody(14))
            case .flexible:
                VStack(spacing: 10) {
                    PinSegmentedPicker(
                        options: [(value: FlexDay.weekday, label: "Weekday"),
                                  (value: FlexDay.weekend, label: "Weekend")],
                        selection: $flexDay
                    )
                    PinSegmentedPicker(
                        options: [(value: FlexMeal.lunch, label: "Lunch"),
                                  (value: FlexMeal.dinner, label: "Dinner")],
                        selection: $flexMeal
                    )
                }
            }
        }
    }

    // MARK: - Size

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepperRow(title: "Total needed",
                       value: $neededPeople,
                       range: minNeeded...maxPeople, // ≥2 so a plan is always a group
                       suffix: "people")
            stepperRow(title: "Already joined",
                       value: $currentPeople,
                       range: 1...neededPeople,
                       suffix: "people")
            Text("Me + \(max(currentPeople - 1, 0)) more already joined")
                .font(.pinSubtitle(12))
                .foregroundStyle(Color.pinInkMuted)
        }
    }

    private func stepperRow(title: LocalizedStringKey, value: Binding<Int>, range: ClosedRange<Int>, suffix: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .font(.pinBody(14))
                .foregroundStyle(Color.pinInk)
                .lineLimit(1)
            Spacer(minLength: 8)
            HStack(spacing: 6) {
                // Concat two Text views so the number stays a number and the
                // suffix gets localized via the catalog. Pin it to one line and
                // let it keep its intrinsic width so "3 people" never wraps on
                // narrower devices.
                (Text(verbatim: "\(value.wrappedValue) ") + Text(suffix))
                    .font(.pinBody(14, weight: .medium).monospacedDigit())
                    .foregroundStyle(Color.pinInk)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Stepper("", value: value, in: range)
                    .labelsHidden()
                    .tint(Color.pinClay)
                    .fixedSize()
            }
        }
    }

    // MARK: - Preference

    private var preferenceSection: some View {
        PinSegmentedPicker(
            options: [
                (value: GenderPreference.any,    label: "Anyone"),
                (value: GenderPreference.female, label: "Female"),
                (value: GenderPreference.male,   label: "Male")
            ],
            selection: $genderPreference
        )
    }

    // MARK: - Notes

    private var notesSection: some View {
        TextField("e.g. Looking for 2 more for lunch deal", text: $notes, axis: .vertical)
            .font(.pinBody(15))
            .foregroundStyle(Color.pinInk)
            .tint(Color.pinClay)
            .lineLimit(3, reservesSpace: true)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.pinCream)
            )
    }

    // MARK: - Error

    /// `msg` is a runtime error from the network — rendered verbatim, no catalog lookup.
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

    // MARK: - Helpers

    private static func generateEventCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let suffix = String((0..<3).map { _ in chars[Int.random(in: 0..<chars.count)] })
        return "PT\(suffix)"
    }

    // MARK: - Submit

    private func prefillIfEditing() {
        guard let p = existingPlan else { return }
        timeType = p.timeType
        scheduledAt = p.scheduledAt
        flexDay = p.flexDay ?? .weekday
        flexMeal = p.flexMeal ?? .lunch
        neededPeople = p.neededPeople
        currentPeople = p.currentPeople
        notes = p.notes
        genderPreference = p.genderPreference
    }

    private func submit() {
        let uid  = authViewModel.uid
        let name = authViewModel.displayName
        guard !uid.isEmpty else { return }

        let now = Date()
        let schedDate: Date
        let expiry: Date
        switch timeType {
        case .asap:
            schedDate = now
            expiry    = now.addingTimeInterval(2 * 3600)
        case .scheduled:
            schedDate = scheduledAt
            expiry    = scheduledAt.addingTimeInterval(3600)
        case .flexible:
            schedDate = now
            expiry    = now.addingTimeInterval(7 * 24 * 3600)
        }
        let isAsap = (timeType == .asap)
        let storedFlexDay: FlexDay?  = (timeType == .flexible) ? flexDay  : nil
        let storedFlexMeal: FlexMeal? = (timeType == .flexible) ? flexMeal : nil

        let plan: Plan
        if let existing = existingPlan {
            plan = Plan(
                id: existing.id,
                restaurantId: existing.restaurantId,
                restaurantName: existing.restaurantName,
                creatorId: existing.creatorId,
                creatorName: existing.creatorName,
                creatorAvatarURL: existing.creatorAvatarURL,
                isAsap: isAsap,
                scheduledAt: schedDate,
                neededPeople: neededPeople,
                currentPeople: currentPeople,
                memberIds: existing.memberIds,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt: expiry,
                reportedBy: existing.reportedBy,
                timeType: timeType,
                flexDay: storedFlexDay,
                flexMeal: storedFlexMeal,
                genderPreference: genderPreference,
                attendanceConfirmedAt: existing.attendanceConfirmedAt,
                eventCode: existing.eventCode ?? Self.generateEventCode()
            )
        } else {
            plan = Plan(
                id: UUID().uuidString.lowercased(),
                restaurantId: restaurant.id,
                restaurantName: restaurant.name,
                creatorId: uid,
                creatorName: name,
                creatorAvatarURL: authViewModel.avatarURL,
                isAsap: isAsap,
                scheduledAt: schedDate,
                neededPeople: neededPeople,
                currentPeople: currentPeople,
                memberIds: [uid],
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt: expiry,
                reportedBy: [],
                timeType: timeType,
                flexDay: storedFlexDay,
                flexMeal: storedFlexMeal,
                genderPreference: genderPreference,
                attendanceConfirmedAt: nil,
                eventCode: Self.generateEventCode()
            )
        }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                if isEditing {
                    try await planVM.updatePlan(plan)
                } else {
                    try await planVM.createPlan(plan)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
