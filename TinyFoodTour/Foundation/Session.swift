import Foundation
import Combine

// MARK: - Session
// Lightweight auth-state singleton for Social Sprint services.
// Wraps AuthViewModel's published user so services don't need @EnvironmentObject.
//
// Bind once at app startup:  Session.shared.bind(to: authVM)
// Then in services:          Session.shared.userId, Session.shared.clientId

@MainActor
final class Session: ObservableObject {
    static let shared = Session()

    @Published private(set) var userId: String?        = nil
    @Published private(set) var userHandle: String?    = nil
    @Published private(set) var isSignedIn             = false

    private var cancellables = Set<AnyCancellable>()
    private init() {}

    /// Call once from TinyFoodTourApp.init or .task to bind auth state.
    func bind(to authVM: AuthViewModel) {
        authVM.$currentUser
            .receive(on: RunLoop.main)
            .sink { [weak self] user in
                self?.userId    = user?.id
                self?.isSignedIn = user != nil
            }
            .store(in: &cancellables)
    }

    /// Guest device ID — stable across reinstalls (Keychain).
    var clientId: String { DeviceIdentity.clientId }

    /// Authenticated UID when signed in, stable device ID for guests.
    var actingId: String { userId ?? clientId }

    /// True when this actingId matches a given author ID (for ownership checks).
    func owns(_ authorId: String?) -> Bool {
        guard let authorId else { return false }
        return authorId == userId || authorId == clientId
    }
}
