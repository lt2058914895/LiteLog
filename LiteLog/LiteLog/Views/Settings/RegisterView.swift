import SwiftUI

struct RegisterView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedCountry = CountryCode.defaultCountry
    @State private var showCountryPicker = false
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var smsCode = ""
    @State private var isLoading = false
    @State private var codeButtonDisabled = false
    @State private var codeCountdown = 60
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
            .sheet(isPresented: $showCountryPicker) {
                countryPickerSheet
            }
            .errorAlert(manager: errorAlertManager)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var cardView: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("register.title", comment: ""))
                .font(.title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            
            inputFields
            
            registerButton
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: Color(.systemGray5).opacity(0.5), radius: 20, x: 0, y: 10)
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
    }
    
    private var inputFields: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("login.phone", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(.secondaryLabel))
                
                HStack(spacing: 12) {
                    countryCodePicker
                    
                    inputField(
                        text: $phoneNumber,
                        keyboardType: .phonePad,
                        placeholder: NSLocalizedString("login.phone.placeholder", comment: "")
                    )
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(NSLocalizedString("login.sms.code", comment: ""))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(Color(.secondaryLabel))
                
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
            
            VStack(alignment: .leading, spacing: 8) {
                secureInputField(
                    title: NSLocalizedString("login.password", comment: ""),
                    text: $password,
                    placeholder: NSLocalizedString("login.password.placeholder", comment: "")
                )
                
                Text(NSLocalizedString("register.password.rule", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray2))
            }
            
            secureInputField(
                title: NSLocalizedString("register.confirm.password", comment: ""),
                text: $confirmPassword,
                placeholder: NSLocalizedString("register.confirm.password.placeholder", comment: "")
            )
        }
    }
    
    private func inputField(text: Binding<String>, keyboardType: UIKeyboardType, placeholder: String) -> some View {
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
    
    private var countryCodePicker: some View {
        Button(action: {
            hideKeyboard()
            showCountryPicker = true
        }) {
            HStack(spacing: 4) {
                Text(selectedCountry.dialCode)
                    .font(.body)
                    .fontWeight(.medium)
                
                Image(systemName: "chevron.down")
                    .font(.caption)
                    .foregroundColor(Color(.systemGray4))
            }
            .frame(height: 50)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
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
    
    private var registerButton: some View {
        Button(action: register) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(NSLocalizedString("action.register", comment: ""))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .disabled(isLoading || !canRegister)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isLoading || !canRegister ? Color.gray : Color.primaryBlue)
        .cornerRadius(12)
        .shadow(color: isLoading || !canRegister ? .clear : Color.primaryBlue.opacity(0.3), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: canRegister)
    }
    
    private var bottomLinks: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text(NSLocalizedString("register.have.account", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(Color(.secondaryLabel))
                
                Button(NSLocalizedString("action.login", comment: "")) {
                    hideKeyboard()
                    dismiss()
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
    
    private var canRegister: Bool {
        guard phoneNumber.count >= 7 && phoneNumber.count <= 15 else { return false }
        guard smsCode.count >= 4 else { return false }
        guard password.count >= 6 else { return false }
        guard password == confirmPassword else { return false }
        return true
    }
    
    private func sendSmsCode() {
        guard phoneNumber.count >= 7 && phoneNumber.count <= 15 else { return }
        
        codeButtonDisabled = true
        codeCountdown = 60
        hasSentCode = true
        startCountdown()
        
        Task {
            do {
                let fullPhoneNumber = "\(selectedCountry.dialCode)\(phoneNumber)"
                let success = try await APIService.shared.sendSMSCode(phone: fullPhoneNumber, type: "register")
                
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
    
    private func register() {
        isLoading = true
        let fullPhoneNumber = "\(selectedCountry.dialCode)\(phoneNumber)"
        
        Task {
            do {
                let response = try await APIService.shared.register(phone: fullPhoneNumber, code: smsCode, password: password)
                
                await MainActor.run {
                    self.isLoading = false
                    
                    if response.success, let userInfo = response.userInfo {
                        self.settingsManager.login(with: userInfo)
                        self.dismiss()
                    } else {
                        self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: response.message ?? NSLocalizedString("register.error", comment: ""))
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: NSLocalizedString("register.error", comment: ""))
                }
            }
        }
    }
    
    private var countryPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(CountryCode.commonCountries) { country in
                    HStack {
                        Text(country.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(country.dialCode)
                            .font(.body)
                            .foregroundColor(Color(.secondaryLabel))
                        
                        if selectedCountry.code == country.code {
                            Image(systemName: "checkmark")
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCountry = country
                        showCountryPicker = false
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(NSLocalizedString("login.select.country", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        showCountryPicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct RegisterView_Previews: PreviewProvider {
    static var previews: some View {
        RegisterView()
            .environmentObject(SettingsManager.shared)
    }
}
