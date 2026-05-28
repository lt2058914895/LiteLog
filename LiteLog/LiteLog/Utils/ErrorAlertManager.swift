import SwiftUI
import Combine

class ErrorAlertManager: ObservableObject {
    @Published var isPresented = false
    @Published var title = ""
    @Published var message = ""
    
    func show(title: String, message: String) {
        self.title = title
        self.message = message
        self.isPresented = true
    }
    
    func dismiss() {
        self.isPresented = false
    }
}

extension View {
    func errorAlert(manager: ErrorAlertManager) -> some View {
        self.alert(manager.title, isPresented: Binding(get: { manager.isPresented }, set: { manager.isPresented = $0 })) {
            Button(NSLocalizedString("action.ok", comment: ""), role: .cancel) {
                manager.dismiss()
            }
        } message: {
            Text(manager.message)
        }
    }
}
