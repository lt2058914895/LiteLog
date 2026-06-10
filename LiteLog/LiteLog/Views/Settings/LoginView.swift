import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    enum LoginType {
        case password
        case smsCode
    }
    
    @State private var loginType: LoginType = .password
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var smsCode = ""
    @State private var isLoading = false
    @State private var codeButtonDisabled = false
    @State private var codeCountdown = 60
    @State private var showRegister = false
    @State private var showResetPassword = false
    @State private var hasSentCode = false
    
    @StateObject private var errorAlertManager = ErrorAlertManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 32) {                        
                        cardView
                        
                        bottomLinks
                    }
                    .padding()
                }
                .onTapGesture { hideKeyboard() }
            }
            .navigationBarHidden(true)
            .background(
                LinearGradient(gradient: Gradient(colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(settingsManager)
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
                    .environmentObject(settingsManager)
            }
            .errorAlert(manager: errorAlertManager)
            .onChange(of: settingsManager.isLoggedIn) { isLoggedIn in
                if isLoggedIn {
                    dismiss()
                }
            }
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var cardView: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("login.title", comment: ""))
                .font(.title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            
            loginTypeSegment
            
            inputFields
            
            loginButton
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color(.systemGray5).opacity(0.5), radius: 20, x: 0, y: 10)
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
    }
    
    private var loginTypeSegment: some View {
        HStack(spacing: 8) {
            Button(action: { 
                hideKeyboard()
                loginType = .password 
            }) {
                Text(NSLocalizedString("login.type.password", comment: ""))
                    .font(.subheadline)
                    .fontWeight(loginType == .password ? .semibold : .regular)
                    .foregroundColor(loginType == .password ? .white : .primaryBlue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(loginType == .password ? Color.primaryBlue : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(12)
            }
            
            Button(action: { 
                hideKeyboard()
                loginType = .smsCode 
            }) {
                Text(NSLocalizedString("login.type.sms", comment: ""))
                    .font(.subheadline)
                    .fontWeight(loginType == .smsCode ? .semibold : .regular)
                    .foregroundColor(loginType == .smsCode ? .white : .primaryBlue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(loginType == .smsCode ? Color.primaryBlue : Color.primaryBlue.opacity(0.1))
                    .cornerRadius(12)
            }
        }
    }
    
    private var inputFields: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("login.phone", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                inputField(
                    text: $phoneNumber,
                    keyboardType: .phonePad,
                    placeholder: NSLocalizedString("login.phone.placeholder", comment: "")
                )
            }
            
            if loginType == .password {
                secureInputField(
                    title: NSLocalizedString("login.password", comment: ""),
                    text: $password,
                    placeholder: NSLocalizedString("login.password.placeholder", comment: "")
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("login.sms.code", comment: ""))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        inputField(
                            text: $smsCode,
                            keyboardType: .numberPad,
                            placeholder: NSLocalizedString("login.sms.code.placeholder", comment: "")
                        )
                        
                        Button(action: sendSmsCode) {
                            Text(codeButtonDisabled ? "\(codeCountdown)s" : (hasSentCode ? NSLocalizedString("login.resend.code", comment: "") : NSLocalizedString("login.get.code", comment: "")))
                                .font(.subheadline)
                                .foregroundColor(codeButtonDisabled || phoneNumber.count < 7 ? .gray : .primaryBlue)
                                .frame(height: 50)
                                .frame(width: 100)
                                .background((codeButtonDisabled || phoneNumber.count < 7) ? Color.gray.opacity(0.1) : Color.primaryBlue.opacity(0.1))
                                .cornerRadius(12)
                        }
                        .disabled(codeButtonDisabled || phoneNumber.count < 7)
                    }
                }
            }
        }
    }
    
    private func inputField(text: Binding<String>, keyboardType: UIKeyboardType, placeholder: String, width: CGFloat = .infinity) -> some View {
        ZStack(alignment: .trailing) {
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .font(.body)
                .frame(height: 50)
                .padding(.horizontal, 16)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            
            if !text.wrappedValue.isEmpty {
                Button(action: { text.wrappedValue = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(.systemGray4))
                        .padding(.trailing, 12)
                }
            }
        }
    }
    
    private func secureInputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(Color(.secondaryLabel))
            
            ZStack(alignment: .trailing) {
                SecureField(placeholder, text: text)
                    .font(.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                if !text.wrappedValue.isEmpty {
                    Button(action: { text.wrappedValue = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray4))
                            .padding(.trailing, 12)
                    }
                }
            }
        }
    }
    
    private var loginButton: some View {
        Button(action: login) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(NSLocalizedString("action.login", comment: ""))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .disabled(isLoading || !canLogin)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isLoading || !canLogin ? Color.gray : Color.primaryBlue)
        .cornerRadius(12)
        .shadow(color: isLoading || !canLogin ? .clear : Color.primaryBlue.opacity(0.3), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: canLogin)
    }
    
    private var bottomLinks: some View {
        VStack(spacing: 12) {
            if loginType == .password {
                HStack(spacing: 12) {
                    Button(NSLocalizedString("login.forgot.password", comment: "")) {
                        hideKeyboard()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    
                    Button(NSLocalizedString("login.reset.password", comment: "")) {
                        hideKeyboard()
                        showResetPassword = true
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primaryBlue)
                }
            }
            
            HStack(spacing: 4) {
                Text(NSLocalizedString("login.no.account", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(NSLocalizedString("login.register", comment: "")) {
                    hideKeyboard()
                    showRegister = true
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primaryBlue)
            }
        }
        .padding(.bottom, 40)
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
    }
    
    private var canLogin: Bool {
        guard phoneNumber.count >= 7 && phoneNumber.count <= 15 else { return false }
        if loginType == .password {
            return password.count >= 6
        } else {
            return smsCode.count == 6
        }
    }
    
    private func sendSmsCode() {
        guard phoneNumber.count >= 7 && phoneNumber.count <= 15 else { return }
        
        codeButtonDisabled = true
        codeCountdown = 60
        hasSentCode = true
        startCountdown()
        
        Task {
            do {
                let fullPhoneNumber = "+86\(phoneNumber)"
                let success = try await APIService.shared.sendSMSCode(phone: fullPhoneNumber)
                
                if !success {
                    await MainActor.run {
                        self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: NSLocalizedString("login.sms.send.failed", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage: String
                    if let apiError = error as? APIError {
                        errorMessage = apiError.errorDescription ?? "未知错误"
                    } else if let localizedError = error as? LocalizedError {
                        errorMessage = localizedError.errorDescription ?? "未知错误"
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: errorMessage)
                }
            }
        }
    }
    
    private func startCountdown() {
        Task {
            for i in (1...60).reversed() {
                await MainActor.run {
                    codeCountdown = i
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            await MainActor.run {
                codeCountdown = 60
                codeButtonDisabled = false
            }
        }
    }
    
    private func login() {
        isLoading = true
        let fullPhoneNumber = "+86\(phoneNumber)"
        
        Task {
            do {
                let response: AuthResponse
                
                if loginType == .password {
                    response = try await APIService.shared.login(phone: fullPhoneNumber, password: password)
                } else {
                    response = try await APIService.shared.loginWithSMSCode(phone: fullPhoneNumber, code: smsCode)
                }
                
                await MainActor.run {
                    self.isLoading = false
                    
                    if response.success, let userInfo = response.userInfo {
                        self.settingsManager.login(with: userInfo)
                    } else {
                        self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: response.message ?? NSLocalizedString("login.error", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    let errorMessage: String
                    if let apiError = error as? APIError {
                        errorMessage = apiError.errorDescription ?? "未知错误"
                    } else if let localizedError = error as? LocalizedError {
                        errorMessage = localizedError.errorDescription ?? "未知错误"
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: errorMessage)
                }
            }
        }
    }
    
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(SettingsManager.shared)
    }
}
