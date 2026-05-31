import SwiftUI

struct CreatePollSheet: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject var pollsVM: PollsViewModel
    @Binding var isPresented: Bool

    @State private var question = ""
    @State private var options: [String] = ["", ""]
    @State private var isSubmitting = false

    private var canPost: Bool {
        !question.trimmingCharacters(in: .whitespaces).isEmpty
            && options.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count >= 2
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.pinCream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        section("Question") {
                            TextField("Where should we eat?", text: $question)
                                .pinTextField()
                        }

                        section("Options") {
                            VStack(spacing: 10) {
                                ForEach(options.indices, id: \.self) { i in
                                    TextField("Option \(i + 1)", text: $options[i])
                                        .pinTextField()
                                }
                                if options.count < 6 {
                                    Button {
                                        options.append("")
                                    } label: {
                                        Label("Add option", systemImage: "plus.circle")
                                            .font(.pinButton(14))
                                            .foregroundStyle(Color.pinClay)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("New poll")
                        .font(.pinBody(15, weight: .medium))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                        .font(.pinButton(15))
                        .foregroundStyle(Color.pinInk)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") { submit() }
                        .font(.pinButton(15))
                        .foregroundStyle(canPost ? Color.pinClay : Color.pinInkMuted)
                        .disabled(!canPost || isSubmitting)
                }
            }
            .toolbarBackground(Color.pinCream, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            PinSectionHeader(title: title)
            VStack(alignment: .leading, spacing: 10) {
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

    private func submit() {
        let cleanOptions = options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let cleanQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        Task {
            await pollsVM.createPoll(
                question: cleanQuestion,
                options: cleanOptions,
                userId: authViewModel.uid,
                userName: authViewModel.displayName
            )
            isSubmitting = false
            isPresented = false
        }
    }
}

// MARK: - Text field modifier

private struct PinTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.pinBody(15))
            .foregroundStyle(Color.pinInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.pinCream)
            )
            .tint(Color.pinClay)
    }
}

private extension View {
    func pinTextField() -> some View { modifier(PinTextFieldModifier()) }
}
