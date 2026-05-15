import SwiftUI

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var feedbackType: FeedbackType = .suggestion
    @State private var message: String = ""
    @State private var email: String = ""
    @State private var allowContact: Bool = false
    @State private var isAnonymous: Bool = false
    @State private var showingSuccess = false
    @State private var isSubmitting = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    enum FeedbackType: String, CaseIterable, Identifiable {
        case bug = "feedback.type.bug"
        case suggestion = "feedback.type.suggestion"
        case praise = "feedback.type.praise"
        case other = "feedback.type.other"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .bug: return "ladybug.fill"
            case .suggestion: return "lightbulb.fill"
            case .praise: return "heart.fill"
            case .other: return "ellipsis.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .bug: return .red
            case .suggestion: return .blue
            case .praise: return .pink
            case .other: return .gray
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(NSLocalizedString("feedback.type", comment: "")) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(FeedbackType.allCases) { type in
                            Button(action: { feedbackType = type }) {
                                VStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                        .font(.system(size: 18))
                                        .foregroundColor(feedbackType == type ? .white : type.color)
                                    Text(NSLocalizedString(type.rawValue, comment: ""))
                                        .font(.caption2)
                                        .foregroundColor(feedbackType == type ? .white : .primaryText)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(feedbackType == type ? type.color : Color.secondaryBackground)
                                .cornerRadius(8)
                                .shadow(color: feedbackType == type ? type.color.opacity(0.3) : .clear, radius: 2)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets())
                        }
                    }
                }
                
                Section {
                    TextEditor(text: $message)
                        .frame(height: 150)
                        .scrollContentBackground(.hidden)
                        .background(Color.secondaryBackground)
                        .cornerRadius(8)
                } header: {
                    Text(NSLocalizedString("feedback.content", comment: ""))
                } footer: {
                    Text("\(message.count)/500")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }
                
                Section {
                    Toggle(isOn: $isAnonymous) {
                        Text(NSLocalizedString("feedback.anonymous", comment: ""))
                    }
                    
                    if !isAnonymous {
                        Toggle(isOn: $allowContact) {
                            Text(NSLocalizedString("feedback.allow.contact", comment: ""))
                        }
                        
                        if allowContact {
                            TextField(NSLocalizedString("feedback.email", comment: ""), text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(.vertical, 8)
                        }
                    }
                }
                
                Section {
                    Text(NSLocalizedString("feedback.privacy.note", comment: ""))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.leading)
                }
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .navigationTitle(NSLocalizedString("feedback.title", comment: ""))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: submitFeedback) {
                        if isSubmitting {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                Text(NSLocalizedString("action.submitting", comment: ""))
                            }
                        } else {
                            Text(NSLocalizedString("action.submit", comment: ""))
                        }
                    }
                    .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .sheet(isPresented: $showingSuccess) {
                FeedbackSuccessView(dismiss: dismiss)
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.ok", comment: "")) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func submitFeedback() {
        isSubmitting = true
        
        let feedback = UserFeedback(
            type: feedbackType.rawValue,
            message: message,
            email: isAnonymous ? nil : (allowContact ? email : nil),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            deviceInfo: "\(UIDevice.current.model) - \(UIDevice.current.systemVersion)"
        )
        
        Task {
            do {
                try await APIService.shared.submitFeedback(feedback)
                FeedbackManager.shared.submit(feedback)
                
                DispatchQueue.main.async {
                    isSubmitting = false
                    showingSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct FeedbackSuccessView: View {
    var dismiss: DismissAction
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.primaryBlue)
                
                Text(NSLocalizedString("feedback.thank.you", comment: ""))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primaryText)
                
                Text(NSLocalizedString("feedback.appreciate", comment: ""))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    dismiss()
                }) {
                    Text(NSLocalizedString("action.ok", comment: ""))
                        .primaryButtonStyle()
                }
                .padding(.top, 16)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    FeedbackView()
}
