import SwiftUI
import Combine

class ErrorAlertManager: ObservableObject {
    @Published var isPresented = false
    @Published var title = ""
    @Published var message = ""
    private var completion: (() -> Void)?
    
    func show(title: String, message: String) {
        self.title = title
        self.message = message
        self.completion = nil
        self.isPresented = true
    }
    
    func show(title: String, message: String, completion: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.completion = completion
        self.isPresented = true
    }
    
    func showError(_ message: String) {
        self.title = NSLocalizedString("error.title", comment: "")
        self.message = message
        self.completion = nil
        self.isPresented = true
    }
    
    func dismiss() {
        self.isPresented = false
        if let completion = self.completion {
            DispatchQueue.main.async {
                completion()
            }
        }
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