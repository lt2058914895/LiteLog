import SwiftUI

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var copiedItem: ContactItem?

    private let email = "2058914895@qq.com"
    private let wechat = "SweetLili_91"

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    header

                    VStack(spacing: 0) {
                        contactRow(
                            item: .email,
                            icon: emailIcon,
                            title: NSLocalizedString("contact.email.label", comment: ""),
                            value: email
                        )

                        Divider()
                            .padding(.leading, 60)

                        contactRow(
                            item: .wechat,
                            icon: wechatIcon,
                            title: NSLocalizedString("contact.wechat.label", comment: ""),
                            value: wechat
                        )
                    }
                    .background(colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 5)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity)
            }

            if let copiedItem {
                copyToast(item: copiedItem)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle(NSLocalizedString("settings.contact", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Text(NSLocalizedString("contact.page.title", comment: ""))
                .font(.title2.weight(.bold))
                .foregroundColor(.primaryText)
                .multilineTextAlignment(.center)

            Text(NSLocalizedString("contact.page.subtitle", comment: ""))
                .font(.subheadline)
                .foregroundColor(.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
    }

    private func contactRow(
        item: ContactItem,
        icon: some View,
        title: String,
        value: String
    ) -> some View {
        Button {
            copy(value, item: item)
        } label: {
            HStack(spacing: 14) {
                icon
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondaryText)

                    Text(value)
                        .font(.title3.weight(.medium))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer(minLength: 8)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.primaryBlue)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 17)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: NSLocalizedString("contact.copy.accessibility", comment: ""),
                title
            )
        )
    }

    private var emailIcon: some View {
        ZStack {
            Circle()
                .fill(Color.primaryBlue)
            Image(systemName: "at")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
        }
    }

    private var wechatIcon: some View {
        Image(systemName: "message.fill")
            .font(.system(size: 29, weight: .medium))
            .foregroundColor(Color(hex: "4CCB5B"))
    }

    private func copy(_ value: String, item: ContactItem) {
        UIPasteboard.general.string = value
        HapticManager.light()

        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            copiedItem = item
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeOut(duration: 0.2)) {
                if copiedItem == item {
                    copiedItem = nil
                }
            }
        }
    }

    private func copyToast(item: ContactItem) -> some View {
        VStack {
            Spacer()
            Label(
                String(
                    format: NSLocalizedString("contact.copy.success", comment: ""),
                    item.displayName
                ),
                systemImage: "checkmark.circle.fill"
            )
            .font(.subheadline.weight(.medium))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.78))
            .clipShape(Capsule())
            .padding(.bottom, 30)
        }
        .allowsHitTesting(false)
    }

    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
}

private enum ContactItem: Equatable {
    case email
    case wechat

    var displayName: String {
        switch self {
        case .email:
            return NSLocalizedString("contact.email.label", comment: "")
        case .wechat:
            return NSLocalizedString("contact.wechat.label", comment: "")
        }
    }
}
