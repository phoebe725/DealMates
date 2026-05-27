import SwiftUI

struct CreatePlanView: View {
    let restaurant: Restaurant
    let existingPlan: Plan?
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Form state
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
    private let maxPeople = 10

    init(restaurant: Restaurant, planVM: PlanViewModel, existingPlan: Plan? = nil) {
        self.restaurant = restaurant
        self.planVM = planVM
        self.existingPlan = existingPlan
    }

    private var isEditing: Bool { existingPlan != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Time section
                Section(header: Label("Time", systemImage: "clock")) {
                    Picker("Type", selection: $timeType) {
                        Text("ASAP").tag(PlanTimeType.asap)
                        Text("Specific").tag(PlanTimeType.scheduled)
                        Text("Flexible").tag(PlanTimeType.flexible)
                    }
                    .pickerStyle(.segmented)

                    switch timeType {
                    case .asap:
                        EmptyView()
                    case .scheduled:
                        DatePicker("Pick a time",
                                   selection: $scheduledAt,
                                   in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                    case .flexible:
                        Picker("Day", selection: $flexDay) {
                            Text("Weekday").tag(FlexDay.weekday)
                            Text("Weekend").tag(FlexDay.weekend)
                        }
                        .pickerStyle(.segmented)

                        Picker("Meal", selection: $flexMeal) {
                            Text("Lunch").tag(FlexMeal.lunch)
                            Text("Dinner").tag(FlexMeal.dinner)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                // Group size section
                Section(header: Label("Group size", systemImage: "person.3")) {
                    Stepper(
                        value: $neededPeople,
                        in: minPeople...maxPeople
                    ) {
                        HStack {
                            Text("Total needed")
                            Text("\(neededPeople) people")
                                .bold()
                        }
                    }
                    Stepper(
                        value: $currentPeople,
                        in: minPeople...neededPeople
                    ) {
                        HStack {
                            Text("Currently joined")
                            Text("\(currentPeople) people")
                                .bold()
                        }
                    }
                    Text("You + \(currentPeople - 1) more already joined")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Gender preference section
                Section(header: Label("Preference", systemImage: "person.crop.circle")) {
                    Picker("Gender preference", selection: $genderPreference) {
                        Text("Open to any").tag(GenderPreference.any)
                        Text("Female only").tag(GenderPreference.female)
                        Text("Male only").tag(GenderPreference.male)
                    }
                    .pickerStyle(.segmented)
                }

                // Notes section
                Section(header: Label("Notes (optional)", systemImage: "text.bubble")) {
                    TextField("e.g. Looking for 2 more for lunch deal", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                // Error
                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Plan" : "New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button(isEditing ? "Save" : "Create") { submit() }
                            .bold()
                    }
                }
            }
            .onAppear { prefillIfEditing() }
        }
    }

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

    // MARK: - Submit

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
            // 7-day open window for flexible plans
            schedDate = now
            expiry    = now.addingTimeInterval(7 * 24 * 3600)
        }
        let isAsap = (timeType == .asap)
        let storedFlexDay: FlexDay?  = (timeType == .flexible) ? flexDay  : nil
        let storedFlexMeal: FlexMeal? = (timeType == .flexible) ? flexMeal : nil

        let plan: Plan
        if let existing = existingPlan {
            plan = Plan(
                id:               existing.id,
                restaurantId:     existing.restaurantId,
                restaurantName:   existing.restaurantName,
                creatorId:        existing.creatorId,
                creatorName:      existing.creatorName,
                creatorAvatarURL: existing.creatorAvatarURL,
                isAsap:           isAsap,
                scheduledAt:      schedDate,
                neededPeople:     neededPeople,
                currentPeople:    currentPeople,
                memberIds:        existing.memberIds,
                notes:            notes.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt:        expiry,
                reportedBy:       existing.reportedBy,
                timeType:         timeType,
                flexDay:          storedFlexDay,
                flexMeal:         storedFlexMeal,
                genderPreference: genderPreference,
                attendanceConfirmedAt: existing.attendanceConfirmedAt
            )
        } else {
            plan = Plan(
                id:               UUID().uuidString.lowercased(),
                restaurantId:     restaurant.id,
                restaurantName:   restaurant.name,
                creatorId:        uid,
                creatorName:      name,
                creatorAvatarURL: authViewModel.avatarURL,
                isAsap:           isAsap,
                scheduledAt:      schedDate,
                neededPeople:     neededPeople,
                currentPeople:    currentPeople,
                memberIds:        [uid],
                notes:            notes.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt:        expiry,
                reportedBy:       [],
                timeType:         timeType,
                flexDay:          storedFlexDay,
                flexMeal:         storedFlexMeal,
                genderPreference: genderPreference,
                attendanceConfirmedAt: nil
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
