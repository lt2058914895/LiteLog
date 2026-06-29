import SwiftUI
import UIKit

extension Notification.Name {
    static let showProfileEditor = Notification.Name("showProfileEditor")
}

extension UIDevice {
    static var isPad: Bool {
        current.userInterfaceIdiom == .pad
    }
    
    static var isPhone: Bool {
        current.userInterfaceIdiom == .phone
    }
}

extension View {
    func adaptiveSheet<Item, Content>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, content: @escaping (Item) -> Content) -> some View where Item: Identifiable, Content: View {
        self.sheet(item: item, onDismiss: onDismiss, content: content)
    }
    
    func adaptiveSheet<Content>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, content: @escaping () -> Content) -> some View where Content: View {
        self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
    }
    
    func tabBarHidden(_ hidden: Bool) -> some View {
        self.modifier(TabBarHiddenModifier(hidden: hidden))
    }
}

struct TabBarHiddenModifier: ViewModifier {
    let hidden: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                if hidden {
                    DispatchQueue.main.async {
                        UITabBar.appearance().isHidden = true
                        findTabBarController()?.tabBar.isHidden = true
                    }
                }
            }
            .onDisappear {
                if hidden {
                    DispatchQueue.main.async {
                        UITabBar.appearance().isHidden = false
                        findTabBarController()?.tabBar.isHidden = false
                    }
                }
            }
    }
    
    private func findTabBarController() -> UITabBarController? {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            return findTabBarController(in: rootViewController)
        }
        return nil
    }
    
    private func findTabBarController(in viewController: UIViewController) -> UITabBarController? {
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }
        
        for child in viewController.children {
            if let found = findTabBarController(in: child) {
                return found
            }
        }
        
        if let presented = viewController.presentedViewController {
            return findTabBarController(in: presented)
        }
        
        return nil
    }
}

extension Color {
    static let primaryBlue = Color(hex: "4A90E2")
    static let lightBlue = Color(hex: "7EB3F1")
    static let darkBlue = Color(hex: "3A7BC8")

    static let cardBackground = Color(.systemBackground)
    static let secondaryBackground = Color(.secondarySystemBackground)
    static let tertiaryBackground = Color(.tertiarySystemBackground)

    static let primaryText = Color(.label)
    static let secondaryText = Color(.secondaryLabel)
    static let tertiaryText = Color(.tertiaryLabel)

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct AdaptiveCardBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color(.secondarySystemBackground) : .white)
    }
}

extension View {
    func adaptiveCardBackground() -> some View {
        self.modifier(AdaptiveCardBackground())
    }
}

extension View {
    func cardStyle() -> some View {
        self
            .adaptiveCardBackground()
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.primaryBlue)
            .cornerRadius(12)
    }

    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(.primaryBlue)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.primaryBlue.opacity(0.1))
            .cornerRadius(12)
    }
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    var startOfYear: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: self)
        return calendar.date(from: components) ?? self
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    var startOfQuarter: Date {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: self)
        let quarterMonth = ((month - 1) / 3) * 3 + 1
        var components = calendar.dateComponents([.year], from: self)
        components.month = quarterMonth
        components.day = 1
        return calendar.date(from: components) ?? self
    }

    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }

    func daysBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay, to: date.startOfDay)
        return components.day ?? 0
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("date.format.short", comment: "")
        return formatter.string(from: self)
    }

    var mediumDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: self)
    }

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("date.format.month.year", comment: "")
        return formatter.string(from: self)
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

extension Array where Element == Double {
    var average: Double? {
        guard !isEmpty else { return nil }
        return reduce(0, +) / Double(count)
    }
}

extension Double {
    func formatted(decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f", self)
    }

    var weightString: String {
        formatted(decimals: 1)
    }

    var bmiString: String {
        formatted(decimals: 1)
    }
    
    /// 智能数值格式化：根据实际小数位数显示
    /// - 如果是整数，不显示小数位
    /// - 如果有1位小数，显示1位
    /// - 如果有2位小数，显示2位
    var smartFormatted: String {
        let rounded = (self * 100).rounded() / 100
        
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        } else if (rounded * 10).rounded() / 10 == rounded {
            return String(format: "%.1f", rounded)
        } else {
            return String(format: "%.2f", rounded)
        }
    }
}

extension Image {
    func asUIImage() -> UIImage? {
        let controller = UIHostingController(rootView: self)
        controller.view.frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: controller.view.bounds.size)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }
}

extension UIImage {
    func scaledToSize(_ size: CGSize) -> UIImage {
        // 先修复图片方向
        let normalizedImage = self.normalizedImage()
        
        UIGraphicsBeginImageContextWithOptions(size, false, UIScreen.main.scale)
        defer { UIGraphicsEndImageContext() }
        
        // 使用 max 比例确保图片填充整个区域，类似 scaledToFill
        let aspectRatio = max(size.width / normalizedImage.size.width, size.height / normalizedImage.size.height)
        let newSize = CGSize(width: normalizedImage.size.width * aspectRatio, height: normalizedImage.size.height * aspectRatio)
        
        // 居中裁剪
        let origin = CGPoint(x: (size.width - newSize.width) / 2, y: (size.height - newSize.height) / 2)
        normalizedImage.draw(in: CGRect(origin: origin, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
    
    private func normalizedImage() -> UIImage {
        if self.imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(self.size, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: self.size.width / 2, y: self.size.height / 2)
        
        switch self.imageOrientation {
        case .down:
            context.rotate(by: .pi)
        case .left:
            context.rotate(by: -.pi / 2)
        case .right:
            context.rotate(by: .pi / 2)
        case .upMirrored:
            context.scaleBy(x: -1, y: 1)
        case .downMirrored:
            context.rotate(by: .pi)
            context.scaleBy(x: -1, y: 1)
        case .leftMirrored:
            context.rotate(by: -.pi / 2)
            context.scaleBy(x: -1, y: 1)
        case .rightMirrored:
            context.rotate(by: .pi / 2)
            context.scaleBy(x: -1, y: 1)
        case .up:
            break
        @unknown default:
            break
        }
        
        context.translateBy(x: -self.size.width / 2, y: -self.size.height / 2)
        self.draw(in: CGRect(origin: .zero, size: self.size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
