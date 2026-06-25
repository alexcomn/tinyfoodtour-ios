import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = ProfileViewModel()

    @State private var selectedTour: Tour?
    @State private var renamingToken: String?
    @State private var renameDraft = ""
    @State private var selectedPhoto: ProfilePhoto?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileHeader
                    if !BadgesService.earned(completedCount: vm.completedToursCount).isEmpty {
                        Divider().padding(.vertical, 4)
                        badgesRow
                    }
                    statsRow
                    Divider().padding(.vertical, 8)
                    savedToursSection
                    if !vm.allTours.isEmpty {
                        Divider().padding(.vertical, 8)
                        tourHistorySection
                    }
                    if !vm.photos.isEmpty {
                        Divider().padding(.vertical, 8)
                        photosSection
                    }
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .scaledFont(size: 15)
                            .foregroundColor(Color("SlateMid"))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color("Primary"))
                }
            }
            .sheet(isPresented: $showSettings) {
                if let userId = authVM.currentUser?.id {
                    ProfileSettingsView(
                        userId: userId,
                        currentHandle: vm.handle,
                        currentBio: vm.bio,
                        currentIsPublic: vm.isPublic,
                        onSave: { h, b, pub in vm.applySettingsSave(handle: h, bio: b, isPublic: pub) }
                    )
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
            .sheet(item: $selectedPhoto) { photo in
                PhotoFullScreenView(url: photo.url, neighborhood: photo.neighborhood)
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
                        .scaledFont(size: 13, weight: .medium)
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
                            .scaledFont(size: 12)
                            .foregroundColor(Color("SlateMid"))
                    }
                    .buttonStyle(.plain)
                }
            }

            if !vm.handle.isEmpty {
                Text("@\(vm.handle)")
                    .scaledFont(size: 13)
                    .foregroundColor(Color("SlateMid"))
            } else if let email = authVM.currentUser?.email {
                Text(email)
                    .scaledFont(size: 13)
                    .foregroundColor(Color("SlateMid"))
            }

            if !vm.bio.isEmpty {
                Text(vm.bio)
                    .scaledFont(size: 13)
                    .foregroundColor(Color("TFTSlate"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("PizzaCrust"))
    }

    // MARK: - Badges
    private var badgesRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BADGES")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(Color("SlateMid"))
                .tracking(1.5)
                .padding(.horizontal, 20)
                .padding(.top, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(BadgesService.earned(completedCount: vm.completedToursCount)) { badge in
                        BadgePill(badge: badge)
                    }
                    if let next = BadgesService.nextUnearned(completedCount: vm.completedToursCount) {
                        BadgePill(badge: next, locked: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Stats
    // Row 1: tour-level stats (completed · saved · favourites)
    // Row 2: discovery stats (stops visited · neighbourhoods) — only shown once
    //        visited_restaurants has data, so new users see a clean 3-stat layout.
    private var statsRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 32) {
                statPill(value: vm.completedToursCount, label: "completed")
                statPill(value: vm.savedTours.count, label: "saved")
                statPill(value: vm.favoritesCount, label: "favourites")
            }
            if vm.totalStopsVisited > 0 || vm.neighborhoodsExplored > 0 {
                Divider()
                HStack(spacing: 32) {
                    statPill(value: vm.totalStopsVisited, label: "stops visited")
                    statPill(value: vm.neighborhoodsExplored, label: "neighbourhoods")
                }
            }
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
                .scaledFont(size: 11)
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
                emptyState("No saved tours yet.")
            } else {
                ForEach(vm.savedTours) { profileTour in
                    SavedTourProfileRow(
                        profileTour: profileTour,
                        onTap: { loadAndShowTour(profileTour) },
                        onRename: {
                            renameDraft = profileTour.displayName
                            renamingToken = profileTour.shareToken
                        },
                        onRemove: { Task { await vm.removeTour(token: profileTour.shareToken, savedTourId: profileTour.savedTourId) } }
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

    // MARK: - Tour History
    private var tourHistorySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Tour History (\(vm.allTours.count))")
            ForEach(vm.allTours) { tour in
                HistoryTourRow(
                    profileTour: tour,
                    onTap: { loadAndShowTour(tour) },
                    onShare: {
                        let url = URL(string: "tinyfoodtour://tour/\(tour.shareToken)")!
                        let items: [Any] = ["\(tour.displayName) — a Tiny Food Tour", url]
                        let av = UIActivityViewController(activityItems: items, applicationActivities: nil)
                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let root = scene.windows.first?.rootViewController {
                            root.present(av, animated: true)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Photos
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Your Photos (\(vm.photos.count))")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.photos) { photo in
                        Button {
                            selectedPhoto = photo
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                AsyncImage(url: URL(string: photo.url)) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    case .failure:
                                        Color("CreamDark")
                                            .overlay(Image(systemName: "photo")
                                                .foregroundColor(Color("SlateMid").opacity(0.4)))
                                    default:
                                        Color("CreamDark")
                                            .overlay(ProgressView().tint(Color("SlateMid")))
                                    }
                                }
                                .frame(width: 110, height: 110)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                // Neighbourhood label
                                Text(photo.neighborhood)
                                    .scaledFont(size: 10, weight: .medium)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(.black.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .padding(6)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
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
            .scaledFont(size: 15)
            .foregroundColor(Color("Radish"))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .scaledFont(size: 13, weight: .semibold)
            .foregroundColor(Color("SlateMid"))
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 8)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .scaledFont(size: 13)
            .foregroundColor(Color("SlateMid"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
    }
}

// MARK: - History tour row (share button instead of rename/delete)
struct HistoryTourRow: View {
    let profileTour: ProfileTour
    let onTap: () -> Void
    let onShare: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(profileTour.displayName)
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(Color("Foreground"))
                    HStack(spacing: 4) {
                        Text("\(profileTour.stopCount) stop\(profileTour.stopCount == 1 ? "" : "s")")
                        if let date = profileTour.formattedDate {
                            Text("·").foregroundColor(Color("SlateMid").opacity(0.5))
                            Text(date)
                        }
                    }
                    .scaledFont(size: 12)
                    .foregroundColor(Color("SlateMid"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: onShare) {
                Image(systemName: "square.and.arrow.up")
                    .scaledFont(size: 13)
                    .foregroundColor(Color("SlateMid"))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        Divider().padding(.leading, 20)
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
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(Color("Foreground"))
                    // Secondary line: stop count · date saved
                    HStack(spacing: 4) {
                        Text("\(profileTour.stopCount) stop\(profileTour.stopCount == 1 ? "" : "s")")
                        if let date = profileTour.formattedDate {
                            Text("·").foregroundColor(Color("SlateMid").opacity(0.5))
                            Text(date)
                        }
                    }
                    .scaledFont(size: 12)
                    .foregroundColor(Color("SlateMid"))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // Rename
            Button(action: onRename) {
                Image(systemName: "pencil")
                    .scaledFont(size: 13)
                    .foregroundColor(Color("SlateMid"))
                    .frame(width: 32, height: 32)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
            }
            .buttonStyle(.plain)

            // Remove
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .scaledFont(size: 13)
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

// MARK: - Favourite row (enhanced: cuisine type + directions link)
struct FavouriteRow: View {
    let spot: FavouriteSpot

    private var directionsURL: URL? {
        let query = [spot.name, spot.neighborhood].compactMap { $0 }.joined(separator: " ")
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://maps.google.com/?q=\(encoded)")
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .scaledFont(size: 12)
                .foregroundColor(Color("Radish"))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(spot.name)
                    .scaledFont(size: 14)
                    .foregroundColor(Color("Foreground"))

                // Cuisine · neighbourhood secondary line
                let parts: [String] = [
                    spot.cuisineType.map { $0.replacingOccurrences(of: "_", with: " ").capitalized }
                        .flatMap { $0.isEmpty ? nil : $0 },
                    spot.neighborhood.flatMap { $0.isEmpty ? nil : $0 }
                ].compactMap { $0 }

                if !parts.isEmpty {
                    Text(parts.joined(separator: " · "))
                        .scaledFont(size: 12)
                        .foregroundColor(Color("SlateMid"))
                }
            }

            Spacer()

            // Directions button
            if let url = directionsURL {
                Link(destination: url) {
                    Image(systemName: "map")
                        .scaledFont(size: 14)
                        .foregroundColor(Color("SlateMid"))
                        .frame(width: 32, height: 32)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.primary.opacity(0.12)))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        Divider().padding(.leading, 56)
    }
}

// MARK: - Full-screen photo viewer
struct PhotoFullScreenView: View {
    let url: String
    let neighborhood: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { phase in
                switch phase {
                case .success(let img):
                    img
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failure:
                    VStack(spacing: 12) {
                        Image(systemName: "photo.slash")
                            .scaledFont(size: 36)
                            .foregroundColor(.white.opacity(0.4))
                        Text("Photo unavailable")
                            .scaledFont(size: 14)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                default:
                    ProgressView().tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Top bar: neighbourhood label + close button
            HStack {
                Text(neighborhood)
                    .scaledFont(size: 13, weight: .medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black.opacity(0.45))
                    .clipShape(Capsule())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(size: 26)
                        .foregroundColor(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
        .presentationBackground(.black)
    }
}
