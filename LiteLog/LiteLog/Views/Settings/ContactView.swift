import SwiftUI

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
            List {
                Section {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(.primaryBlue)
                        Text(NSLocalizedString("settings.email", comment: ""))
                        Spacer()
                        Text("2058914895@qq.com")
                            .foregroundColor(.secondaryText)
                    }

                    HStack {
                        Image(systemName: "message.circle.fill")
                            .foregroundColor(.green)
                        Text(NSLocalizedString("settings.wechat", comment: ""))
                        Spacer()
                        Text("SweetLili_91")
                            .foregroundColor(.secondaryText)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
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
    
    private var backButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.primaryBlue)
        }
    }
}
