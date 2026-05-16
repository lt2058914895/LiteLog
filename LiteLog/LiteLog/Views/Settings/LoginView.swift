import SwiftUI

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    enum LoginType {
        case password
        case smsCode
    }
    
    @State private var loginType: LoginType = .password
    @State private var selectedCountry = CountryCode.defaultCountry
    @State private var showCountryPicker = false
    @State private var phoneNumber = ""
    @State private var password = ""
    @State private var smsCode = ""
    @State private var isLoading = false
    @State private var codeButtonDisabled = false
    @State private var codeCountdown = 60
    
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
                LinearGradient(gradient: Gradient(colors: [Color.primaryBlue.opacity(0.05), Color.primaryBlue.opacity(0.1)]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .sheet(isPresented: $showCountryPicker) {
                countryPickerSheet
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
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
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
                
                HStack(spacing: 12) {
                    countryCodePicker
                    
                    inputField(
                        text: $phoneNumber,
                        keyboardType: .phonePad,
                        placeholder: NSLocalizedString("login.phone.placeholder", comment: "")
                    )
                }
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
                            Text(codeButtonDisabled ? "\(codeCountdown)s" : NSLocalizedString("login.get.code", comment: ""))
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
        TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .font(.body)
            .frame(height: 50)
            .padding(.horizontal, 16)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
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
                    .foregroundColor(.gray)
            }
            .frame(height: 50)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    private func secureInputField(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            SecureField(placeholder, text: text)
                .font(.body)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
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
                Button(NSLocalizedString("login.forgot.password", comment: "")) {
                    hideKeyboard()
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Text(NSLocalizedString("login.no.account", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button(NSLocalizedString("login.register", comment: "")) {
                    hideKeyboard()
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
            return !password.isEmpty
        } else {
            return smsCode.count >= 4
        }
    }
    
    private func sendSmsCode() {
        guard phoneNumber.count >= 7 && phoneNumber.count <= 15 else { return }
        
        codeButtonDisabled = true
        
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
            if codeCountdown > 1 {
                codeCountdown -= 1
            } else {
                codeCountdown = 60
                codeButtonDisabled = false
                timer.invalidate()
            }
        }
    }
    
    private func login() {
        isLoading = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            settingsManager.login(userId: "\(selectedCountry.dialCode)\(phoneNumber)")
            dismiss()
            isLoading = false
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
                            .foregroundColor(.secondary)
                        
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

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(SettingsManager.shared)
    }
}
