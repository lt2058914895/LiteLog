import SwiftUI

struct UserInfoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager
    
    @State private var nickname = UserProfile.defaultProfile.nickname
    @State private var avatarImage: UIImage?
    @State private var showImagePicker = false
    @State private var showLogoutAlert = false
    
    @StateObject private var errorAlertManager = ErrorAlertManager()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    avatarSection
                    
                    inputSection
                    
                    saveButton
                    
                    logoutButton
                }
                .padding()
            }
            .navigationTitle(NSLocalizedString("profile.edit.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("action.cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                imagePicker
            }
            .errorAlert(manager: errorAlertManager)
            .alert(NSLocalizedString("profile.logout.confirm", comment: ""), isPresented: $showLogoutAlert) {
                Button(NSLocalizedString("action.cancel", comment: ""), role: .cancel) {}
                Button(NSLocalizedString("action.logout", comment: ""), role: .destructive) {
                    logout()
                }
            }
        }
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
                            .scaledToFill()
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.primaryBlue, lineWidth: 2)
                            )
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.primaryBlue)
                    }
                    
                    Image(systemName: "camera")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.primaryBlue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            
            Text(NSLocalizedString("profile.edit.avatar.hint", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondary)
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
            saveProfile()
        }) {
            Text(NSLocalizedString("action.save", comment: ""))
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(nickname.isEmpty ? Color.gray : Color.primaryBlue)
                .cornerRadius(12)
                .shadow(color: nickname.isEmpty ? .clear : Color.primaryBlue.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .disabled(nickname.isEmpty)
    }
    
    private var logoutButton: some View {
        Button(action: {
            showLogoutAlert = true
        }) {
            Text(NSLocalizedString("action.logout", comment: ""))
                .font(.subheadline)
                .foregroundColor(.primaryBlue)
        }
    }
    
    private var imagePicker: some View {
        ImagePicker(image: $avatarImage)
    }
    
    private func saveProfile() {
        // 保存用户信息逻辑
        dismiss()
    }
    
    private func logout() {
        settingsManager.logout()
        dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct UserInfoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        UserInfoEditorView()
            .environmentObject(SettingsManager.shared)
    }
}