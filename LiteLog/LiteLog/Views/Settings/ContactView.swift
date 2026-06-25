import SwiftUI

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
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
            .navigationBarItems(leading: Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primaryBlue)
            })
        }
    }
}
