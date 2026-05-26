import SwiftUI

struct CreatePlanView: View {
    let restaurant: Restaurant
    let existingPlan: Plan?
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var isASAP = false
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var neededPeople = 3
    @State private var currentPeople = 1
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
                    Toggle("ASAP", isOn: $isASAP.animation())
                    if !isASAP {
                        DatePicker("Pick a time",
                                   selection: $scheduledAt,
                                   in: Date()...,
                                   displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
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
        isASAP = p.isAsap
        scheduledAt = p.scheduledAt
        neededPeople = p.neededPeople
        currentPeople = p.currentPeople
        notes = p.notes
    }

    // MARK: - Submit

    private func submit() {
        let uid  = authViewModel.uid
        let name = authViewModel.displayName
        guard !uid.isEmpty else { return }

        let now        = Date()
        let schedDate  = isASAP ? now : scheduledAt
        let expiry     = isASAP
            ? now.addingTimeInterval(2 * 3600)         // 2-hour window for ASAP
            : scheduledAt.addingTimeInterval(3600)     // 1 hour after scheduled time

        let plan: Plan
        if let existing = existingPlan {
            plan = Plan(
                id:               existing.id,
                restaurantId:     existing.restaurantId,
                restaurantName:   existing.restaurantName,
                creatorId:        existing.creatorId,
                creatorName:      existing.creatorName,
                creatorAvatarURL: existing.creatorAvatarURL,
                isAsap:           isASAP,
                scheduledAt:      schedDate,
                neededPeople:     neededPeople,
                currentPeople:    currentPeople,
                memberIds:        existing.memberIds,
                notes:            notes.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt:        expiry,
                reportedBy:       existing.reportedBy
            )
        } else {
            plan = Plan(
                id:               UUID().uuidString.lowercased(),
                restaurantId:     restaurant.id,
                restaurantName:   restaurant.name,
                creatorId:        uid,
                creatorName:      name,
                creatorAvatarURL: authViewModel.avatarURL,
                isAsap:           isASAP,
                scheduledAt:      schedDate,
                neededPeople:     neededPeople,
                currentPeople:    currentPeople,
                memberIds:        [uid],
                notes:            notes.trimmingCharacters(in: .whitespacesAndNewlines),
                expiresAt:        expiry,
                reportedBy:       []
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
