import SwiftUI

struct UserInfoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var nickname = ""
    @State private var avatarImage: UIImage?
    @State private var avatarUrl: String = ""
    @State private var showImagePicker = false
    @State private var isLoading = false
    
    init() {
        _nickname = State(initialValue: SettingsManager.shared.nickname)
        _avatarUrl = State(initialValue: SettingsManager.shared.avatarUrl)
    }
    
    @StateObject private var errorAlertManager = ErrorAlertManager()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    avatarSection
                    
                    inputSection
                    
                    saveButton
                }
                .padding()
            }
            .ignoresSafeArea(.keyboard)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(NSLocalizedString("profile.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarItems(leading: backButton)
            .sheet(isPresented: $showImagePicker) {
                imagePicker
            }
            .errorAlert(manager: errorAlertManager)
            .onTapGesture {
                hideKeyboard()
            }
        }
    }
    
    private var backButton: some View {
        Button(action: {
            dismiss()
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 20, weight: .medium))
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
                    // 优先级：1. 用户新选择的头像 2. 缓存的头像 3. 默认头像
                    if let image = avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(Circle())
                    } else if let cachedImage = settingsManager.cachedAvatarImage {
                        Image(uiImage: cachedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipped()
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.primaryBlue)
                    }
                    
                    Image(systemName: "camera")
                        .resizable()
                        .frame(width: 18, height: 18)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.primaryBlue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .onAppear {
                loadAndCacheAvatarIfNeeded()
            }
            
            Text(NSLocalizedString("profile.edit.avatar.hint", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private func loadAndCacheAvatarIfNeeded() {
        guard avatarImage == nil, !avatarUrl.isEmpty else { return }
        
        // 如果已有缓存且URL没变，不需要重新加载
        if settingsManager.isAvatarCached {
            return
        }
        
        Task {
            if let url = URL(string: avatarUrl), let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                settingsManager.updateCachedAvatar(with: image)
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
                    .font(.body)
                    .frame(height: 50)
                    .padding(.horizontal, 16)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                
                if !nickname.isEmpty {
                    Button(action: { nickname = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray4))
                            .padding(.trailing, 12)
                    }
                }
            }
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            Task {
                await saveProfile()
            }
        }) {
            if isLoading {
                ProgressView()
                    .foregroundColor(.white)
            } else {
                Text(NSLocalizedString("action.save", comment: ""))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(nickname.isEmpty || isLoading ? Color.gray : Color.primaryBlue)
        .cornerRadius(12)
        .shadow(color: (nickname.isEmpty || isLoading) ? .clear : Color.primaryBlue.opacity(0.3), radius: 10, x: 0, y: 4)
        .disabled(nickname.isEmpty || isLoading)
    }
    
    private var imagePicker: some View {
        ImagePicker(image: $avatarImage, isPresented: $showImagePicker)
    }
    
    private func saveProfile() async {
        guard !nickname.isEmpty else { return }
        
        hideKeyboard()
        isLoading = true
        
        do {
            // 上传头像（如果有选择新头像）
            let avatarUrl = await uploadAvatarIfNeeded()
            
            // 如果用户选择了新头像但上传失败，中断保存流程
            if avatarImage != nil && avatarUrl == nil {
                // 头像上传失败，恢复显示原头像
                self.avatarImage = nil
                isLoading = false
                return
            }
            
            // 调用更新用户信息接口
            let response = try await APIService.shared.updateProfile(nickname: nickname, avatarUrl: avatarUrl)
            
            if response.success {
                updateLocalProfile(nickname: response.nickname ?? nickname, avatarUrl: response.avatarUrl)
                dismiss()
            } else {
                // 更新失败，恢复显示原头像
                self.avatarImage = nil
                errorAlertManager.showError(response.message ?? "更新失败")
            }
        } catch {
            // 网络错误，恢复显示原头像
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
            } else {
                // 否则清除旧缓存，下次会重新加载
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
