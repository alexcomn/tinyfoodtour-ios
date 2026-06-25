import SwiftUI

// MARK: - Toast model

enum ToastStyle { case success, error, info }

struct ToastMessage: Identifiable, Equatable {
    let id    = UUID()
    let text  : String
    let style : ToastStyle

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

// MARK: - ToastManager
// Max 1 toast visible at a time. Sonner-style top-center, 3s auto-dismiss.
// Usage: ToastManager.shared.show("Tour saved!", style: .success)

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var current: ToastMessage? = nil

    private var dismissTask: Task<Void, Never>?
    private init() {}

    func show(_ text: String, style: ToastStyle = .info) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            current = ToastMessage(text: text, style: style)
        }
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.25)) { self?.current = nil }
            }
        }
    }

    func dismiss() {
        dismissTask?.cancel()
        withAnimation(.easeOut(duration: 0.2)) { current = nil }
    }
}
