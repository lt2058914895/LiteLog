import SwiftUI
import UIKit

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
        Group {
            if UIDevice.isPad {
                self.popover(item: item, content: content)
            } else {
                self.sheet(item: item, onDismiss: onDismiss, content: content)
            }
        }
    }
    
    func adaptiveSheet<Content>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, content: @escaping () -> Content) -> some View where Content: View {
        Group {
            if UIDevice.isPad {
                self.popover(isPresented: isPresented, content: content)
            } else {
                self.sheet(isPresented: isPresented, onDismiss: onDismiss, content: content)
            }
        }
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

extension View {
    func cardStyle() -> some View {
        self
            .background(Color.cardBackground)
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
}
