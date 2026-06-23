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
        TextField(placeholder, text: $text)
            .keyboardType(keyboardType)
            .onChange(of: text) { _, newValue in
                text = formatNumericInput(newValue)
            }
    }
    
    private func formatNumericInput(_ input: String) -> String {
        // 移除所有非数字和非小数点字符
        let filtered = input.filter { "0123456789.".contains($0) }
        
        // 处理小数点
        let parts = filtered.components(separatedBy: ".")
        if parts.count > 2 {
            // 多个小数点，只保留第一个
            let integerPart = parts.first ?? ""
            let decimalPart = parts.dropFirst().joined().prefix(maxDecimals)
            return "\(integerPart).\(decimalPart)"
        } else if parts.count == 2 {
            // 一个小数点，限制小数位数
            let integerPart = parts[0]
            let decimalPart = parts[1].prefix(maxDecimals)
            return "\(integerPart).\(decimalPart)"
        } else {
            return filtered
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
