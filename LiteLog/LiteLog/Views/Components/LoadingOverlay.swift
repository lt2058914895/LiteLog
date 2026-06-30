import SwiftUI

struct LoadingOverlay: View {
    var isLoading: Bool
    var message: String?
    
    var body: some View {
        ZStack {
            if isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.opacity)
                
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.primaryBlue)
                    
                    if let message = message {
                        Text(message)
                            .foregroundColor(.primaryText)
                            .font(.body)
                            .fontWeight(.medium)
                    }
                }
                .padding(32)
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .shadow(radius: 12)
                .transition(.scale)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .zIndex(1000)
    }
}

extension View {
    func loadingOverlay(isLoading: Bool, message: String? = nil) -> some View {
        ZStack {
            self
            LoadingOverlay(isLoading: isLoading, message: message)
        }
    }
}