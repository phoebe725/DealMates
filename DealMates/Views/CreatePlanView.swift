import SwiftUI

struct CreatePlanView: View {
    let restaurant: Restaurant
    @ObservedObject var planVM: PlanViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var isASAP = true
    @State private var scheduledAt = Date().addingTimeInterval(3600)
    @State private var neededPeople = 3
    @State private var currentPeople = 1
    @State private var purpose: PlanPurpose = .either
    @State private var notes = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private let minPeople = 1
    private let maxPeople = 10

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
                    Text("You need \(neededPeople) people total")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Divider()

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

                // Purpose section
                Section(header: Label("Purpose", systemImage: "tag")) {
                    Picker("Purpose", selection: $purpose) {
                        ForEach(PlanPurpose.allCases, id: \.self) { p in
                            Label(p.label, systemImage: p.icon).tag(p)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 4)
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
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Create") { submit() }
                            .bold()
                    }
                }
            }
        }
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

        let plan = Plan(
            id:            UUID().uuidString.lowercased(),
            restaurantId:  restaurant.id,
            restaurantName: restaurant.name,
            creatorId:     uid,
            creatorName:   name,
            creatorAvatarURL: authViewModel.avatarURL,
            isAsap:        isASAP,
            scheduledAt:   schedDate,
            neededPeople:  neededPeople,
            currentPeople: currentPeople,
            memberIds:     [uid],
            purpose:       purpose,
            notes:         notes.trimmingCharacters(in: .whitespacesAndNewlines),
            expiresAt:     expiry,
            reportedBy:    []
        )

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await planVM.createPlan(plan)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}
