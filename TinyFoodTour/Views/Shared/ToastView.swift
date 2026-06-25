import SwiftUI

// MARK: - ToastView
// Top-center banner. Mount once via .toastOverlay() on the WindowGroup root.

struct ToastView: View {
    let toast: ToastMessage

    private var background: Color {
        switch toast.style {
        case .success: return .tftOlive
        case .error:   return .tftRadish
        case .info:    return .tftSlate
        }
    }

    private var icon: String {
        switch toast.style {
        case .success: return "checkmark.circle.fill"
        case .error:   return "exclamationmark.circle.fill"
        case .info:    return "info.circle.fill"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .scaledFont(size: 14)
            Text(toast.text)
                .scaledFont(size: 13, weight: .medium)
                .lineLimit(2)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 24)
    }
}

// MARK: - .toastOverlay() modifier
// Attach to the top-level ZStack in TinyFoodTourApp so toasts float above
// sheets and navigation stacks.

struct ToastOverlayModifier: ViewModifier {
    @ObservedObject private var manager = ToastManager.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = manager.current {
                    ToastView(toast: toast)
                        .padding(.top, 56)
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .opacity
                        ))
                        .onTapGesture { manager.dismiss() }
                        .zIndex(999)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: manager.current)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlayModifier()) }
}

// MARK: - Preview

#Preview {
    VStack {
        ToastView(toast: ToastMessage(text: "Tour saved!", style: .success))
        ToastView(toast: ToastMessage(text: "Couldn't connect — try again", style: .error))
        ToastView(toast: ToastMessage(text: "Link copied to clipboard", style: .info))
    }
    .padding()
    .background(Color.tftCream)
}
