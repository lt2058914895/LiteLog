import SwiftUI

struct ContactView: View {
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
            .navigationTitle(NSLocalizedString("settings.contact", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
