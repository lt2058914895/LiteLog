import SwiftUI

struct NumericTextField: View {
    let placeholder: String
    @Binding var text: String
    let maxDecimals: Int
    let keyboardType: UIKeyboardType
    
    init(_ placeholder: String, text: Binding<String>, maxDecimals: Int = 2, keyboardType: UIKeyboardType = .decimalPad) {
        self.placeholder = placeholder
        self._text = text
        self.maxDecimals = maxDecimals
        self.keyboardType = keyboardType
    }
    
    var body: some View {
        ZStack(alignment: .trailing) {
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .padding(.trailing, 24)
                .onChange(of: text) { newValue in
                    let formatted = NumericInputFormatter.format(
                        newValue,
                        maxDecimals: maxDecimals
                    )
                    if formatted != newValue {
                        text = formatted
                    }
                }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray4))
                }
                .padding(.trailing, 4)
            }
        }
    }
    
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        icon: String,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.secondaryText.opacity(0.5))

            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primaryText)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .primaryButtonStyle()
                }
                .padding(.top, 8)
            }
        }
        .padding(32)
    }
}

struct LoadingView: View {
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
    }
}

struct ErrorView: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)

            Button(action: retryAction) {
                Text(NSLocalizedString("action.confirm", comment: ""))
                    .secondaryButtonStyle()
            }
            .padding(.top, 8)
        }
        .padding(32)
    }
}

struct ProfileToolbarChip: View {
    @EnvironmentObject private var settingsManager: SettingsManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 8) {
                avatar
                    .overlay(Circle().stroke(Color.white.opacity(0.85), lineWidth: 1))

                Text(settingsManager.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: true, vertical: false)
                    .layoutPriority(1)
            }
            .padding(.leading, 5)
            .padding(.trailing, 10)
            .padding(.vertical, 5)
            .background(LinearGradient.profileHeader)
            .clipShape(Capsule())
            .shadow(color: Color.primaryBlue.opacity(0.18), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(NSLocalizedString("profile.title", comment: ""))
    }

    @ViewBuilder
    private var avatar: some View {
        if let image = settingsManager.avatarImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .id(settingsManager.avatarUpdatedToken)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .foregroundColor(.white.opacity(0.9))
        }
    }
}

struct ClearTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: UIFont
    let textColor: UIColor

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.font = font
        textView.textColor = textColor
        textView.text = text.isEmpty ? placeholder : text
        textView.textColor = text.isEmpty ? .secondaryLabel : textColor
        textView.delegate = context.coordinator
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if !text.isEmpty && uiView.text != text {
            uiView.text = text
            uiView.textColor = textColor
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextViewDelegate {
        let parent: ClearTextView

        init(_ parent: ClearTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                parent.text = ""
            } else {
                parent.text = textView.text
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = parent.textColor
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = .secondaryLabel
            }
        }
    }
}
