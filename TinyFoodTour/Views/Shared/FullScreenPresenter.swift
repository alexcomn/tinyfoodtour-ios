import SwiftUI
import UIKit

/// Presents a SwiftUI view using UIKit's .fullScreen modal with .crossDissolve —
/// bypasses iOS 26's zoom presentation animation which leaves views in an offset/scaled
/// coordinate state. UIKit .fullScreen guarantees the view fills screen bounds exactly.
struct FullScreenPresenter<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiVC: UIViewController, context: Context) {
        if isPresented && uiVC.presentedViewController == nil {
            let host = UIHostingController(rootView: content())
            host.modalPresentationStyle = .fullScreen
            host.modalTransitionStyle = .crossDissolve   // fade, not zoom
            host.view.backgroundColor = .clear
            context.coordinator.hosted = host
            uiVC.present(host, animated: true)
        } else if !isPresented, let presented = uiVC.presentedViewController {
            presented.dismiss(animated: true) {
                context.coordinator.hosted = nil
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator {
        var hosted: UIHostingController<Content>?
    }
}

extension View {
    /// Present a full-screen view using UIKit .crossDissolve — avoids iOS 26 zoom
    /// animation coordinate offset that affects both fullScreenCover and NavigationStack.
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
