import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) var dismiss

    let userId: String
    let currentHandle: String
    let currentBio: String
    let currentIsPublic: Bool
    let onSave: (String, String, Bool) -> Void  // handle, bio, isPublic

    @State private var handleDraft: String
    @State private var bioDraft: String
    @State private var isPublicDraft: Bool
    @State private var handleStatus: HandleStatus = .idle
    @State private var isSaving = false
    @State private var checkTask: Task<Void, Never>?

    enum HandleStatus: Equatable { case idle, checking, available, taken, invalid }

    init(userId: String, currentHandle: String, currentBio: String,
         currentIsPublic: Bool, onSave: @escaping (String, String, Bool) -> Void) {
        self.userId = userId
        self.currentHandle = currentHandle
        self.currentBio = currentBio
        self.currentIsPublic = currentIsPublic
        self.onSave = onSave
        _handleDraft = State(initialValue: currentHandle)
        _bioDraft = State(initialValue: currentBio)
        _isPublicDraft = State(initialValue: currentIsPublic)
    }

    private var handleUnchanged: Bool {
        handleDraft.trimmingCharacters(in: .whitespaces).lowercased() == currentHandle.lowercased()
    }

    private var canSave: Bool {
        !isSaving && !handleDraft.trimmingCharacters(in: .whitespaces).isEmpty
            && (handleUnchanged || handleStatus == .available)
            && handleStatus != .invalid && handleStatus != .taken
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 2) {
                            Text("@")
                                .scaledFont(size: 15)
                                .foregroundColor(Color("SlateMid"))
                            TextField("username", text: $handleDraft)
                                .scaledFont(size: 15)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: handleDraft) { _, new in scheduleCheck(new) }
                        }
                        handleHint
                    }
                    .padding(.vertical, 4)
                } header: { Text("Username") }

                Section {
                    ZStack(alignment: .topLeading) {
                        if bioDraft.isEmpty {
                            Text("A short bio…")
                                .scaledFont(size: 14)
                                .foregroundColor(Color("SlateMid").opacity(0.55))
                                .padding(.top, 8).padding(.leading, 4)
                                .allowsHitTesting(false)
                        }
                        TextEditor(text: $bioDraft)
                            .scaledFont(size: 14)
                            .frame(minHeight: 80)
                    }
                } header: { Text("Bio") }

                Section {
                    Toggle("Public profile", isOn: $isPublicDraft)
                        .tint(Color("Primary"))
                    if isPublicDraft {
                        let slug = handleDraft.isEmpty ? "you" : handleDraft.lowercased()
                        Text("Visible at tinyfoodtour.com/u/\(slug)")
                            .scaledFont(size: 12).foregroundColor(Color("SlateMid"))
                    }
                } header: { Text("Visibility") }
                  footer: { if !isPublicDraft { Text("Your profile is private.").scaledFont(size: 12) } }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundColor(Color("SlateMid"))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isSaving {
                        ProgressView().tint(Color("Primary"))
                    } else {
                        Button("Save") { Task { await save() } }
                            .fontWeight(.semibold)
                            .foregroundColor(canSave ? Color("Primary") : Color("SlateMid"))
                            .disabled(!canSave)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var handleHint: some View {
        switch handleStatus {
        case .idle:      EmptyView()
        case .checking:
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.7).tint(Color("SlateMid"))
                Text("Checking…").scaledFont(size: 12).foregroundColor(Color("SlateMid"))
            }
        case .available:
            Label("Available", systemImage: "checkmark.circle.fill")
                .scaledFont(size: 12).foregroundColor(.green)
        case .taken:
            Label("Already taken", systemImage: "xmark.circle.fill")
                .scaledFont(size: 12).foregroundColor(.red)
        case .invalid:
            Text("3–20 characters, letters / numbers / underscores only")
                .scaledFont(size: 12).foregroundColor(Color("SlateMid"))
        }
    }

    private func isValidFormat(_ h: String) -> Bool {
        NSPredicate(format: "SELF MATCHES %@", "^[a-zA-Z0-9_]{3,20}$").evaluate(with: h)
    }

    private func scheduleCheck(_ raw: String) {
        let h = raw.trimmingCharacters(in: .whitespaces)
        checkTask?.cancel()
        guard isValidFormat(h) else { handleStatus = h.isEmpty ? .idle : .invalid; return }
        guard !handleUnchanged else { handleStatus = .idle; return }
        handleStatus = .checking
        checkTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            do {
                let ok: Bool = try await SupabaseService.shared.callRPC(
                    function: "is_handle_available", body: ["_handle": h.lowercased()]
                )
                handleStatus = ok ? .available : .taken
            } catch { handleStatus = .idle }
        }
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        let h = handleDraft.trimmingCharacters(in: .whitespaces).lowercased()
        let b = bioDraft.trimmingCharacters(in: .whitespaces)
        do {
            try await SupabaseService.shared.upsert(
                table: "profiles",
                body: ["id": userId, "handle": h, "bio": b, "is_public": isPublicDraft],
                onConflict: "id"
            )
            onSave(h, b, isPublicDraft)
            dismiss()
        } catch {
            ToastManager.shared.show("Couldn't save — try again.", style: .error)
        }
        isSaving = false
    }
}
