import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = ProfileViewModel()

    @State private var selectedTour: Tour?
    @State private var renamingToken: String?
    @State private var renameDraft = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileHeader
                    statsRow
                    Divider().padding(.vertical, 8)
                    savedToursSection
                    if !vm.favorites.isEmpty {
                        Divider().padding(.vertical, 8)
                        favoritesSection
                    }
                    Divider().padding(.top, 16)
                    signOutButton
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color("Cream"))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color("Primary"))
                }
            }
            .sheet(item: $selectedTour) { tour in
                NavigationStack {
                    ResultsView(tour: tour, isShared: true, generationParams: nil)
                        .environmentObject(authVM)
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("Close") { selectedTour = nil }
                                    .foregroundColor(Color("SlateMid"))
                            }
                        }
                }
            }
            .alert("Rename tour", isPresented: .init(
                get: { renamingToken != nil },
                set: { if !$0 { renamingToken = nil } }
            )) {
                TextField("Tour name", text: $renameDraft)
                Button("Save") {
                    if let token = renamingToken {
                        vm.renameTour(token: token, newName: renameDraft)
                    }
                    renamingToken = nil
                }
                Button("Cancel", role: .cancel) { renamingToken = nil }
            }
        }
        .task {
            if let userId = authVM.currentUser?.id {
                await vm.load(userId: userId)
            }
        }
    }

    // MARK: - Profile header
    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            BrandMarkView(fontSize: 11)
                .padding(.bottom, 4)

            if vm.editingDisplayName {
                HStack(spacing: 8) {
                    TextField("Your name", text: $vm.displayNameDraft)
                        .font(TFTFont.heading(20))
                        .foregroundColor(Color("Foreground"))
                        .submitLabel(.done)
                        .onSubmit {
                            if let id = authVM.currentUser?.id {
                                Task { await vm.saveDisplayName(userId: id) }
                            }
                        }
                    if vm.isSavingName {
                        ProgressView().tint(Color("Radish"))
                    } else {
                        Button("Save") {
                            if let id = authVM.currentUser?.id {
                                Task { await vm.saveDisplayName(userId: id) }
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color("Primary"))
                    }
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(vm.displayName.isEmpty
                         ? (authVM.currentUser?.email?.components(separatedBy: "@").first ?? "Traveller")
                         : vm.displayName)
                        .font(TFTFont.heading(22))
                        .foregroundColor(Color("Foreground"))
                    Button {
                        vm.displayNameDraft = vm.displayName
                        vm.editingDisplayName = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 12))
                            .foregroundColor(Color("SlateMid"))
                    }
                    .buttonStyle(.plain)
                }
            }

            if let email = authVM.currentUser?.email {
                Text(email)
                    .font(.system(size: 13))
                    .foregroundColor(Color("SlateMid"))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("PizzaCrust"))
    }

    // MARK: - Stats
    private var statsRow: some View {
        HStack(spacing: 32) {
            statPill(value: vm.completedToursCount, label: "completed")
            statPill(value: vm.savedTours.count, label: "saved")
            statPill(value: vm.favoritesCount, label: "favourites")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(TFTFont.heading(22))
                .foregroundColor(Color("Primary"))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color("SlateMid"))
        }
    }

    // MARK: - Saved tours
    private var savedToursSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Saved Tours (\(vm.savedTours.count))")

            if vm.isLoading {
                ProgressView().tint(Color("Radish"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if vm.savedTours.isEmpty {
                emptyState("No saved tours yet.", cta: "Build a tour →") {}
            } else {
                ForEach(vm.savedTours) { profileTour in
                    SavedTourProfileRow(
                        profileTour: profileTour,
                        onTap: { loadAndShowTour(profileTour) },
                        onRename: {
                            renameDraft = profileTour.displayName
                            renamingToken = profileTour.shareToken
                        },
                        onRemove: { vm.removeTour(token: profileTour.shareToken) }
                    )
                }
            }
        }
    }

    private func loadAndShowTour(_ profileTour: ProfileTour) {
        Task {
            struct TourRow: Codable {
                let id: String; let neighborhood: String; let vibe: [String]
                let dietary: [String]; let walk_distance: String; let stops: AnyCodable
                let created_at: String; let user_id: String?; let share_token: String
            }
            guard let rows: [TourRow] = try? await SupabaseService.shared.query(
                table: "tours", select: "*",
                filters: ["id": "eq.\(profileTour.id)"]
            ), let row = rows.first else { return }

            let stops: [TourStop]
            if let arr = row.stops.value as? [[String: Any]] {
                stops = arr.filter { $0["_meta"] as? Bool != true }
                    .compactMap { dict -> TourStop? in
                        guard let data = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                        return try? JSONDecoder().decode(TourStop.self, from: data)
                    }
            } else { stops = [] }

            let tour = Tour(id: row.id, neighborhood: row.neighborhood, vibe: row.vibe,
                           dietary: row.dietary, walk_distance: row.walk_distance,
                           stops: stops, created_at: row.created_at,
                           user_id: row.user_id, share_token: row.share_token)
            selectedTour = tour
        }
    }

    // MARK: - Favourites
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Favourites (\(vm.favorites.count))")
            ForEach(vm.favorites) { spot in
                FavouriteRow(spot: spot)
            }
        }
    }

    // MARK: - Sign out
    private var signOutButton: some View {
        Button {
            authVM.signOut()
            dismiss()
        } label: {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                Text("Sign out")
            }
            .font(.system(size: 15))
            .foregroundColor(Color("Radish"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color("SlateMid"))
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func emptyState(_ message: String, cta: String, action: @escaping () -> Void) -> some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(Color("SlateMid"))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
    }
}

// MARK: - Saved tour row with actions
struct SavedTourProfileRow: View {
    let profileTour: ProfileTour
    let onTap: () -> Void
    let onRename: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(profileTour.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Color("Foreground"))
                    Text("\(profileTour.stopCount) stop\(profileTour.stopCount == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(Color("SlateMid"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Rename
            Button(action: onRename) {
                Image(systemName: "pencil")
                    .font(.system(size: 13))
                    .foregroundColor(Color("SlateMid"))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)

            // Remove
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .font(.system(size: 13))
                    .foregroundColor(Color("Radish"))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color("Radish").opacity(0.25)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        Divider().padding(.leading, 20)
    }
}

// MARK: - Favourite row
struct FavouriteRow: View {
    let spot: FavouriteSpot
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 12))
                .foregroundColor(Color("Radish"))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.system(size: 14))
                    .foregroundColor(Color("Foreground"))
                if let n = spot.neighborhood {
                    Text(n)
                        .font(.system(size: 12))
                        .foregroundColor(Color("SlateMid"))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        Divider().padding(.leading, 56)
    }
}
