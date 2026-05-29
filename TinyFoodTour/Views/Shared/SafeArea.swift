import UIKit

extension UIApplication {
    /// Bottom safe area inset (home indicator height on notched devices).
    static var safeAreaBottom: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom) ?? 0
    }
}
