import SwiftUI
import UIKit

/// Presents a SwiftUI view by finding the topmost UIViewController in the key
/// window and calling present(_:animated:false) directly — no SwiftUI presentation
/// layer, no iOS 26 zoom animation, no coordinate transform residue.
struct FullScreenPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()  // zero-size anchor; actual presentation is from window root
    }

    func updateUIViewController(_ uiVC: UIViewController, context: Context) {
        if isPresented && context.coordinator.hosted == nil {
            guard let presenter = topViewController() else { return }
            let host = UIHostingController(rootView: content())
            host.modalPresentationStyle = .fullScreen
            // animated: FALSE — any animation in iOS 26 (even crossDissolve)
            // can apply a residual coordinate transform. Instant transition = clean slate.
            host.view.frame = UIScreen.main.bounds
            context.coordinator.hosted = host
            presenter.present(host, animated: false)
        } else if !isPresented, let host = context.coordinator.hosted {
            host.dismiss(animated: false) {
                context.coordinator.hosted = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var hosted: UIHostingController<Content>?
    }

    /// Walk the key window's view controller hierarchy to find the topmost presenter.
    private func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }),
              let window = scene.windows.first(where: { $0.isKeyWindow }),
              let root = window.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

extension View {
    func uiFullScreen<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        self.background(
            FullScreenPresenter(isPresented: isPresented, content: content)
                .frame(width: 0, height: 0)
        )
    }
}
