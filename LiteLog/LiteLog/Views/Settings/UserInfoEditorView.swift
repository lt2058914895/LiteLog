import SwiftUI

struct UserInfoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var nickname = ""
    @State private var originalNickname = ""
    @State private var avatarImage: UIImage?
    @State private var avatarUrl: String = ""
    @State private var originalAvatarUrl = ""
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var showingSuccessToast = false
    @State private var avatarUploadProgress: Double = 0
    @State private var isUploadingAvatar = false
    
    init() {
        let currentNickname = SettingsManager.shared.nickname
        let currentAvatarUrl = SettingsManager.shared.avatarUrl
        _nickname = State(initialValue: currentNickname)
        _originalNickname = State(initialValue: currentNickname)
        _avatarUrl = State(initialValue: currentAvatarUrl)
        _originalAvatarUrl = State(initialValue: currentAvatarUrl)
    }
    
    @StateObject private var errorAlertManager = ErrorAlertManager()
    
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    hideKeyboard()
                }
            
            ScrollView {
                VStack(spacing: 32) {
                    avatarSection
                    
                    inputSection
                    
                    saveButton
                }
                .padding()
            }
            .ignoresSafeArea(.keyboard)
            
            if showingSuccessToast {
                successToast
            }
        }
            .navigationTitle(NSLocalizedString("profile.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: backButton)
            .tabBarHidden(true)
            .sheet(isPresented: $showImagePicker) {
                imagePicker
            }
            .errorAlert(manager: errorAlertManager)
            .loadingOverlay(isLoading: isLoading, message: NSLocalizedString("profile.saving", comment: ""))
    }
    
    private var successToast: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title)
                Text(NSLocalizedString("action.save.success", comment: ""))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.primaryBlue)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(), value: showingSuccessToast)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
        .onTapGesture {
            showingSuccessToast = false
        }
    }
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private var avatarSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                showImagePicker = true
            }) {
                ZStack(alignment: .bottomTrailing) {
                    if let image = avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    } else if let cachedImage = settingsManager.cachedAvatarImage {
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.primaryBlue.opacity(0.1))
                                .frame(width: 120, height: 120)
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.primaryBlue)
                        }
                    }
                    
                    ZStack {
                        Circle()
                            .fill(Color.primaryBlue)
                            .frame(width: 36, height: 36)
                            .shadow(color: Color.primaryBlue.opacity(0.3), radius: 4, x: 0, y: 2)
                        Image(systemName: "camera")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white)
                    }
                }
            }
            .onAppear {
                loadAndCacheAvatarIfNeeded()
            }
            
            VStack(spacing: 4) {
                Text(NSLocalizedString("profile.edit.avatar.hint", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if avatarImage != nil {
                    Button(action: { avatarImage = nil }) {
                        Text(NSLocalizedString("profile.edit.avatar.remove", comment: ""))
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func loadAndCacheAvatarIfNeeded() {
        guard avatarImage == nil, !avatarUrl.isEmpty else { return }
        
        // 如果已有缓存且URL没变，不需要重新加载
        if settingsManager.isAvatarCached {
            return
        }
        
        Task {
            if let url = URL(string: avatarUrl) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        settingsManager.updateCachedAvatar(with: image)
                    }
                } catch {
                    print("DEBUG: Failed to load avatar: \(error)")
                }
            }
        }
    }
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("profile.edit.nickname", comment: ""))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            ZStack(alignment: .trailing) {
                TextField(NSLocalizedString("profile.edit.nickname.placeholder", comment: ""), text: $nickname)
                    .font(Font(UIFont.systemFont(ofSize: 17, weight: .medium)))
                    .frame(height: 56)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(nickname.isEmpty ? Color(.systemGray4) : Color.primaryBlue, lineWidth: nickname.isEmpty ? 1 : 2)
                            .animation(.easeInOut(duration: 0.2), value: nickname.isEmpty)
                    )
                    .shadow(color: !nickname.isEmpty ? Color.primaryBlue.opacity(0.1) : .clear, radius: 8, x: 0, y: 2)
                
                if !nickname.isEmpty {
                    Button(action: { nickname = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray4))
                            .padding(.trailing, 12)
                            .transition(.opacity.combined(with: .scale))
                            .animation(.easeInOut(duration: 0.2), value: nickname.isEmpty)
                    }
                }
            }
            
            HStack {
                Spacer()
                Text("\(nickname.count)/20")
                    .font(.caption2)
                    .foregroundColor(nickname.count > 20 ? .red : .secondaryText)
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                await saveProfile()
            }
        }) {
            Text(NSLocalizedString("action.save", comment: ""))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(isSaveEnabled ? Color.primaryBlue : Color.gray)
                .cornerRadius(12)
                .shadow(color: isSaveEnabled ? Color.primaryBlue.opacity(0.3) : .clear, radius: 10, x: 0, y: 4)
                .animation(.easeInOut(duration: 0.2), value: isSaveEnabled)
        }
        .disabled(!isSaveEnabled)
    }
    
    private var isSaveEnabled: Bool {
        !nickname.isEmpty && nickname.count <= 20
    }
    
    private var imagePicker: some View {
        ImagePicker(image: $avatarImage, isPresented: $showImagePicker)
    }
    
    private func saveProfile() async {
        hideKeyboard()
        isLoading = true
        
        do {
            var avatarUrl: String? = nil
            if avatarImage != nil {
                avatarUrl = await uploadAvatarIfNeeded()
                
                if avatarUrl == nil {
                    self.avatarImage = nil
                    isLoading = false
                    return
                }
            }
            
            let isNicknameChanged = nickname != originalNickname
            let isAvatarChanged = avatarImage != nil || (avatarUrl != nil && avatarUrl != originalAvatarUrl)
            
            if !isNicknameChanged && !isAvatarChanged {
                isLoading = false
                dismiss()
                return
            }
            
            let response = try await APIService.shared.updateProfile(
                nickname: isNicknameChanged ? nickname : nil,
                avatarUrl: isAvatarChanged ? avatarUrl : nil
            )
            
            if response.success {
                updateLocalProfile(nickname: response.nickname ?? nickname, avatarUrl: response.avatarUrl)
                
                showingSuccessToast = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showingSuccessToast = false
                    dismiss()
                }
            } else {
                self.avatarImage = nil
                errorAlertManager.showError(response.message ?? "更新失败")
            }
        } catch {
            self.avatarImage = nil
            errorAlertManager.showError(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    private func uploadAvatarIfNeeded() async -> String? {
        guard let image = avatarImage else { return nil }
        
        do {
            let response = try await APIService.shared.uploadAvatar(image: image)
            if response.success, let avatarUrl = response.avatarUrl {
                return avatarUrl
            } else {
                errorAlertManager.showError(response.message ?? "头像上传失败")
                return nil
            }
        } catch {
            errorAlertManager.showError(error.localizedDescription)
            return nil
        }
    }
    
    private func updateLocalProfile(nickname: String, avatarUrl: String?) {
        settingsManager.nickname = nickname
        if let avatarUrl = avatarUrl {
            settingsManager.avatarUrl = avatarUrl
            self.avatarUrl = avatarUrl
            // 如果用户选择了新头像，更新缓存
            if let image = avatarImage {
                settingsManager.updateCachedAvatar(with: image)
            } else if avatarUrl != originalAvatarUrl {
                // 只有头像URL发生变化时才清除缓存
                settingsManager.clearCachedAvatar()
            }
        }
    }
}

struct UserInfoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        UserInfoEditorView()
            .environmentObject(SettingsManager.shared)
    }
}
