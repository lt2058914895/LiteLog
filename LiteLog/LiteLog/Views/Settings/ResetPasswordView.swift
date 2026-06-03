import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var selectedCountry = CountryCode.defaultCountry
    @State private var showCountryPicker = false
    @State private var phoneNumber = ""
    @State private var smsCode = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
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
            Text(NSLocalizedString("reset.password.title", comment: ""))
                .font(.title)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
            
            inputFields
            
            resetButton
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
                    title: NSLocalizedString("reset.password.new", comment: ""),
                    text: $newPassword,
                    placeholder: NSLocalizedString("login.password.placeholder", comment: "")
                )
                
                Text(NSLocalizedString("login.password.hint", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(Color(.systemGray2))
            }
            
            secureInputField(
                title: NSLocalizedString("reset.password.confirm", comment: ""),
                text: $confirmPassword,
                placeholder: NSLocalizedString("reset.password.confirm.placeholder", comment: "")
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
    
    private var resetButton: some View {
        Button(action: resetPassword) {
            if isLoading {
                ProgressView()
                    .tint(.white)
            } else {
                Text(NSLocalizedString("reset.password.action", comment: ""))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .disabled(isLoading || !canReset)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(isLoading || !canReset ? Color.gray : Color.primaryBlue)
        .cornerRadius(12)
        .shadow(color: isLoading || !canReset ? .clear : Color.primaryBlue.opacity(0.3), radius: 10, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.2), value: canReset)
    }
    
    private var canReset: Bool {
        guard phoneNumber.count >= 7 && phoneNumber.count <= 15 else { return false }
        guard smsCode.count == 6 else { return false }
        guard newPassword.count >= 6 else { return false }
        guard newPassword == confirmPassword else { return false }
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
    
    private func resetPassword() {
        isLoading = true
        let fullPhoneNumber = "\(selectedCountry.dialCode)\(phoneNumber)"
        
        Task {
            do {
                let response = try await APIService.shared.resetPassword(phone: fullPhoneNumber, code: smsCode, newPassword: newPassword)
                
                await MainActor.run {
                    self.isLoading = false
                    
                    if response.success {
                        self.errorAlertManager.show(title: NSLocalizedString("success.title", comment: ""), message: NSLocalizedString("reset.password.success", comment: "")) {
                            self.dismiss()
                        }
                    } else {
                        self.errorAlertManager.show(title: NSLocalizedString("error.title", comment: ""), message: response.message ?? NSLocalizedString("reset.password.failed", comment: ""))
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

struct ResetPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        ResetPasswordView()
            .environmentObject(SettingsManager.shared)
    }
}