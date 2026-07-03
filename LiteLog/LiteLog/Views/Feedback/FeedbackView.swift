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
            case .bug: return Color(.systemRed)
            case .suggestion: return Color(.systemBlue)
            case .praise: return Color(.systemPink)
            case .other: return Color(.systemGray)
            }
        }
    }

    var body: some View {
            ZStack {
                Color.cardBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // 反馈类型选择
                        VStack(alignment: .leading, spacing: 12) {
                            Text(NSLocalizedString("feedback.type", comment: ""))
                                .font(.headline)
                                .foregroundColor(.primaryText)

                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                ForEach(FeedbackType.allCases) { type in
                                    Button(action: {
                                        feedbackType = type
                                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                    }) {
                                        VStack(spacing: 4) {
                                            Image(systemName: type.icon)
                                                .font(.system(size: 18))
                                                .foregroundColor(feedbackType == type ? .white : type.color)
                                            Text(NSLocalizedString(type.rawValue, comment: ""))
                                                .font(.caption2)
                                                .foregroundColor(feedbackType == type ? .white : .primaryText)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(feedbackType == type ? type.color : Color.secondaryBackground)
                                        .cornerRadius(8)
                                        .shadow(color: feedbackType == type ? type.color.opacity(0.3) : .clear, radius: 2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // 反馈内容输入
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("feedback.content", comment: ""))
                                .font(.headline)
                                .foregroundColor(.primaryText)

                            ClearTextView(
                                text: $message,
                                placeholder: NSLocalizedString("feedback.content.placeholder", comment: ""),
                                font: UIFont.preferredFont(forTextStyle: .subheadline),
                                textColor: .label
                            )
                            .frame(height: 150)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)

                            HStack {
                                Spacer()
                                Text("\(message.count)/500")
                                    .font(.caption)
                                    .foregroundColor(.secondaryText)
                            }
                        }

                        // 匿名反馈和联系方式
                        VStack(spacing: 12) {
                            Toggle(isOn: $isAnonymous) {
                                Text(NSLocalizedString("feedback.anonymous", comment: ""))
                                    .foregroundColor(.primaryText)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .primaryBlue))
                            .onChange(of: isAnonymous) { _ in
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }

                            if !isAnonymous {
                                Toggle(isOn: $allowContact) {
                                    Text(NSLocalizedString("feedback.allow.contact", comment: ""))
                                        .foregroundColor(.primaryText)
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .primaryBlue))
                                .onChange(of: allowContact) { _ in
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }

                                if allowContact {
                                    TextField(NSLocalizedString("feedback.email", comment: ""), text: $email)
                                        .keyboardType(.emailAddress)
                                        .font(.subheadline)
                                        .frame(height: 50)
                                        .padding(.horizontal, 16)
                                        .background(Color(.secondarySystemBackground))
                                        .cornerRadius(12)
                                }
                            }
                        }

                        // 提交按钮
                        Button(action: submitFeedback) {
                            Text(NSLocalizedString("action.submit", comment: ""))
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.primaryBlue)
                                .cornerRadius(12)
                        }
                        .disabled(message.trimmingCharacters(in: .whitespaces).isEmpty)

                        // 隐私提示
                        Text(NSLocalizedString("feedback.privacy.note", comment: ""))
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .multilineTextAlignment(.leading)
                            .padding(.vertical,20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                }
                .contentShape(Rectangle())
                .simultaneousGesture(
                    TapGesture()
                        .onEnded { _ in
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                )
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("feedback.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .sheet(isPresented: $showingSuccess, onDismiss: {
                dismiss()
            }) {
                FeedbackSuccessView()
            }
            .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
                Button(NSLocalizedString("action.ok", comment: "")) {}
            } message: {
                Text(errorMessage)
            }
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .loadingOverlay(isLoading: isSubmitting, message: NSLocalizedString("action.submitting", comment: ""))
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
                try await FeedbackManager.shared.submit(feedback)

                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.showingSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.isSubmitting = false
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                }
            }
        }
    }
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
}

struct FeedbackSuccessView: View {
    @Environment(\.dismiss) private var dismiss

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.cardBackground)
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    FeedbackView()
}
