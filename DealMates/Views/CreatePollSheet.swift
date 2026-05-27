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
            Form {
                Section("Question") {
                    TextField("Where should we eat?", text: $question)
                }

                Section("Options") {
                    ForEach(options.indices, id: \.self) { i in
                        TextField("Option \(i + 1)", text: $options[i])
                    }
                    if options.count < 6 {
                        Button {
                            options.append("")
                        } label: {
                            Label("Add option", systemImage: "plus.circle")
                        }
                    }
                }
            }
            .navigationTitle("New Poll")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post Poll") {
                        submit()
                    }
                    .bold()
                    .disabled(!canPost || isSubmitting)
                }
            }
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
