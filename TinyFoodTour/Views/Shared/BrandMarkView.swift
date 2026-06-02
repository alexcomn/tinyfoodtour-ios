import SwiftUI

// Wordmark font: Fraunces (display serif) per ios-branding-brief.md §1.
// iOS approximation: .system(design: .serif) — New York display serif.
// Tracking 0.25em, uppercase, medium weight.
struct BrandMarkView: View {
    var fontSize: CGFloat = 11

    var body: some View {
        Text("TINY FOOD TOUR")
            .font(.system(size: fontSize, weight: .medium, design: .serif))
            .tracking(fontSize * 0.25)
            .foregroundColor(Color("Foreground"))
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
                .foregroundColor(Color("Foreground"))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(isSelected ? Color("PizzaCrust") : Color("Cream"))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color("Yolk") : Color("Foreground").opacity(0.15), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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
                .background(isEnabled ? Color("Primary") : Color("TFTSlate").opacity(0.25))
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
                    .fill(i <= current ? Color("Radish") : Color("Foreground").opacity(0.12))
                    .frame(height: 3)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Step \(current + 1) of \(total)")
        .accessibilityValue("\(Int(Double(current + 1) / Double(total) * 100))% complete")
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
