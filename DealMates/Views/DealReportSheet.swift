import SwiftUI

/// Lets a user report a wrong/changed price for a restaurant's deal. Submitted to
/// the separate `deal_reports` table as status='pending' — it never overwrites the
/// official offer (mirrors the web Report-price sheet).
struct DealReportSheet: View {
    let restaurantId: String
    let deals: [RestaurantOffer]
    let reporterId: String
    let reporterName: String
    @Binding var isPresented: Bool
    var onSubmitted: () -> Void

    @State private var selectedOfferId: String?
    @State private var priceText = ""
    @State private var note = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !priceText.trimmingCharacters(in: .whitespaces).isEmpty
            || !note.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Spotted a different price? Let us know — we'll review it.")
                            .font(.pinSubtitle(13))
                            .foregroundStyle(Color.pinInkMuted)

                        if !deals.isEmpty {
                            Picker("", selection: $selectedOfferId) {
                                ForEach(deals) { d in
                                    Text(d.displayTitle.isEmpty ? d.shortLabel.text : d.displayTitle)
                                        .tag(Optional(d.id))
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(Color.pinClay)
                        }

                        TextField("Correct price per person (£)", text: $priceText)
                            .keyboardType(.decimalPad)
                            .pinReportField()

                        TextField("Anything else? (optional)", text: $note, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)
                            .pinReportField()

                        if let err = errorMessage {
                            Text(err).font(.pinSubtitle(12)).foregroundStyle(Color.pinClayDeep)
                        }
                    }
                    .padding(20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Report price")
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit report") { submit() }
                        .font(.pinButton(15))
                        .foregroundStyle(canSubmit ? Color.pinClay : Color.pinInkMuted)
                        .disabled(!canSubmit || isSubmitting)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear { selectedOfferId = deals.first?.id }
        }
    }

    private func submit() {
        isSubmitting = true
        errorMessage = nil
        let cleaned = priceText.filter { $0.isNumber || $0 == "." }
        let price = Double(cleaned)
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            do {
                try await DatabaseService.shared.submitDealReport(
                    restaurantId: restaurantId,
                    offerId: selectedOfferId,
                    reporterId: reporterId.isEmpty ? nil : reporterId,
                    reporterName: reporterName.isEmpty ? nil : reporterName,
                    reportedPrice: price,
                    note: trimmedNote.isEmpty ? nil : trimmedNote
                )
                onSubmitted()
                isPresented = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

private struct PinReportFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pinBody(15))
            .foregroundStyle(Color.pinInk)
            .tint(Color.pinClay)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.pinShell))
    }
}

private extension View {
    func pinReportField() -> some View { modifier(PinReportFieldModifier()) }
}
