import SwiftUI

struct UserInfoEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settingsManager: SettingsManager

    @State private var nickname: String
    @State private var originalNickname: String
    @State private var selectedAvatar: UIImage?
    @State private var removeAvatar = false
    @State private var showImagePicker = false
    @State private var showingSuccessToast = false
    @State private var showingError = false

    init() {
        let currentNickname = SettingsManager.shared.nickname
        _nickname = State(initialValue: currentNickname)
        _originalNickname = State(initialValue: currentNickname)
    }

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
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $selectedAvatar, isPresented: $showImagePicker)
        }
        .onChange(of: selectedAvatar) { image in
            if image != nil {
                removeAvatar = false
            }
        }
        .alert(NSLocalizedString("error.title", comment: ""), isPresented: $showingError) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) {}
        } message: {
            Text(NSLocalizedString("profile.avatar.save.failed", value: "无法保存头像，请重试。", comment: ""))
        }
    }

    private var displayedAvatar: UIImage? {
        if let selectedAvatar {
            return selectedAvatar
        }
        return removeAvatar ? nil : settingsManager.avatarImage
    }

    private var avatarSection: some View {
        VStack(spacing: 16) {
            Button {
                showImagePicker = true
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    if let image = displayedAvatar {
                        Image(uiImage: image)
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
                        Image(systemName: "photo")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .foregroundColor(.white)
                    }
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 4) {
                Text(NSLocalizedString("profile.edit.avatar.hint", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if displayedAvatar != nil {
                    Button(NSLocalizedString("profile.edit.avatar.remove", comment: "")) {
                        selectedAvatar = nil
                        removeAvatar = true
                    }
                    .font(.caption)
                    .foregroundColor(.red)
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
                    Button {
                        nickname = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(.systemGray4))
                            .padding(.trailing, 12)
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
        Button(action: saveProfile) {
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
        !nickname.isEmpty && nickname.count <= 20 &&
        (nickname != originalNickname || selectedAvatar != nil || removeAvatar)
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
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
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

    private func saveProfile() {
        hideKeyboard()

        if let selectedAvatar {
            guard settingsManager.saveAvatar(selectedAvatar) else {
                showingError = true
                return
            }
        } else if removeAvatar, !settingsManager.removeAvatar() {
            showingError = true
            return
        }

        settingsManager.nickname = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        HapticManager.success()
        showingSuccessToast = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showingSuccessToast = false
            dismiss()
        }
    }
}

struct UserInfoEditorView_Previews: PreviewProvider {
    static var previews: some View {
        UserInfoEditorView()
            .environmentObject(SettingsManager.shared)
    }
}
