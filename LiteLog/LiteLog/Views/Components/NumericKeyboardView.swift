import SwiftUI

struct NumericKeyboardView: View {
    @Binding var value: String
    let unit: WeightUnit
    let onSubmit: () -> Void

    @State private var isEditing = false

    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        [".", "0", "delete"]
    ]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text(unit.shortName)
                    .font(.headline)
                    .foregroundColor(.secondaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.secondaryBackground)
                    .cornerRadius(8)

                Spacer()
            }
            .padding(.horizontal, 4)

            keysView
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    private var keysView: some View {
        VStack(spacing: 8) {
            ForEach(keys, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func keyButton(_ key: String) -> some View {
        if key == "delete" {
            Button(action: { deleteCharacter() }) {
                Image(systemName: "delete.left")
                    .font(.title2)
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.secondaryBackground)
                    .cornerRadius(12)
            }
        } else {
            Button(action: { appendCharacter(key) }) {
                Text(key)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.secondaryBackground)
                    .cornerRadius(12)
            }
        }
    }

    private func appendCharacter(_ char: String) {
        if char == "." {
            if !value.contains(".") {
                value += char
            }
        } else {
            if value == "0" && char != "." {
                value = char
            } else {
                let parts = value.split(separator: ".")
                if parts.count == 2 && parts[1].count >= 1 {
                    return
                }
                value += char
            }
        }
    }

    private func deleteCharacter() {
        if !value.isEmpty {
            value.removeLast()
        }
    }
}
