import SwiftUI

struct BrandMarkView: View {
    var fontSize: CGFloat = 17

    // Wordmark: "TiNY FOOD TOUR" — lowercase 'i' is intentional (brand quirk)
    var body: some View {
        HStack(spacing: 4) {
            Text("TiNY")
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .foregroundColor(Color("Radish"))
            Text("FOOD")
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .foregroundColor(Color("Yolk"))
            Text("TOUR")
                .font(.system(size: fontSize, weight: .bold, design: .serif))
                .foregroundColor(Color("Radish"))
        }
    }
}

// MARK: - Pill button style used throughout the quiz
struct PillButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(isSelected ? Color("TFTSlate") : Color("TFTSlate"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color("PizzaCrust") : Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color("Radish").opacity(0.5) : Color.primary.opacity(0.12), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CTA button
struct CTAButton: View {
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(isEnabled ? Color("Radish") : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Progress bar
struct QuizProgressBar: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i <= current ? Color("Radish") : Color.primary.opacity(0.1))
                    .frame(height: 3)
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        BrandMarkView()
        PillButton(label: "Date night", isSelected: true) {}
        PillButton(label: "Flying solo", isSelected: false) {}
        CTAButton(title: "Next →", isEnabled: true) {}
        QuizProgressBar(current: 2, total: 7)
            .padding()
    }
    .padding()
}
