import SwiftUI

// MARK: - Models

struct PublicProfile {
    let userId: String
    let displayName: String
    let handle: String
    let bio: String?
    let completedToursCount: Int
}

// MARK: - ViewModel

@MainActor
final class PublicProfileViewModel: ObservableObject {
    @Published private(set) var profile: PublicProfile?
    @Published private(set) var publishedTours: [Tour] = []
    @Published private(set) var badges: [Badge] = []
    @Published private(set) var isLoading = false
    @Published var selectedTour: Tour?

    let handle: String
    init(handle: String) { self.handle = handle }

    func load() async {
        isLoading = true
        defer { isLoading = false }

        struct ProfileRow: Codable {
            let id: String
            let display_name: String?
            let handle: String?
            let bio: String?
            let completed_tours_count: Int?
        }
        guard let rows: [ProfileRow] = try? await SupabaseService.shared.query(
            table: "profiles",
            select: "id,display_name,handle,bio,completed_tours_count",
            filters: ["handle": "eq.\(handle)", "is_public": "eq.true"]
        ), let row = rows.first else { return }

        let pub = PublicProfile(
            userId: row.id,
            displayName: row.display_name ?? "",
            handle: row.handle ?? handle,
            bio: row.bio,
            completedToursCount: row.completed_tours_count ?? 0
        )
        profile = pub
        badges = BadgesService.earned(completedCount: pub.completedToursCount)

        struct TourRow: Codable {
            let id: String; let neighborhood: String; let vibe: [String]
            let dietary: [String]; let walk_distance: String; let stops: AnyCodable
            let created_at: String; let user_id: String?; let share_token: String
            let tour_title: String?; let total_distance_miles: Double?
        }
        let tourRows: [TourRow] = (try? await SupabaseService.shared.query(
            table: "tours",
            select: "*",
            filters: ["published_by": "eq.\(pub.userId)", "is_published": "eq.true"],
            order: "published_at.desc"
        )) ?? []

        publishedTours = tourRows.compactMap { row in
            let stops: [TourStop]
            if let arr = row.stops.value as? [[String: Any]] {
                stops = arr.filter { !($0["_meta"] is [String: Any]) }
                    .compactMap { dict -> TourStop? in
                        guard let d = try? JSONSerialization.data(withJSONObject: dict) else { return nil }
                        return try? JSONDecoder().decode(TourStop.self, from: d)
                    }
            } else { stops = [] }
            return Tour(
                id: row.id, neighborhood: row.neighborhood,
                vibe: row.vibe, dietary: row.dietary,
                walk_distance: row.walk_distance, stops: stops,
                created_at: row.created_at, user_id: row.user_id,
                share_token: row.share_token,
                tourTitle: row.tour_title,
                totalDistanceMiles: row.total_distance_miles
            )
        }
    }
}

// MARK: - View

struct PublicProfileView: View {
    let handle: String
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm: PublicProfileViewModel

    init(handle: String) {
        self.handle = handle
        _vm = StateObject(wrappedValue: PublicProfileViewModel(handle: handle))
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let profile = vm.profile {
                    profileContent(profile)
                } else {
                    notFoundView
                }
            }
            .background(Color("Cream"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color("Primary"))
                }
            }
        }
        .task { await vm.load() }
    }

    @ViewBuilder
    private func profileContent(_ profile: PublicProfile) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                profileHeader(profile)

                if !vm.badges.isEmpty {
                    badgesSection(profile)
                }

                if !vm.publishedTours.isEmpty {
                    Divider().padding(.vertical, 8)
                    toursSection
                } else {
                    emptyToursView
                }
            }
        }
        .sheet(item: $vm.selectedTour) { tour in
            NavigationStack {
                ResultsView(tour: tour, isShared: true, generationParams: nil)
                    .environmentObject(authVM)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") { vm.selectedTour = nil }
                                .foregroundColor(Color("SlateMid"))
                        }
                    }
            }
        }
    }

    private func profileHeader(_ profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BrandMarkView(fontSize: 11).padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(profile.displayName.isEmpty ? "@\(handle)" : profile.displayName)
                    .font(TFTFont.heading(24))
                    .foregroundColor(Color("Foreground"))
                Text("@\(profile.handle)")
                    .scaledFont(size: 13)
                    .foregroundColor(Color("SlateMid"))
            }

            if let bio = profile.bio, !bio.isEmpty {
                Text(bio)
                    .scaledFont(size: 14)
                    .foregroundColor(Color("TFTSlate"))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(profile.completedToursCount)")
                        .font(TFTFont.heading(20)).foregroundColor(Color("Primary"))
                    Text("tours completed").scaledFont(size: 11).foregroundColor(Color("SlateMid"))
                }
            }
            .padding(.top, 6)

            if let url = URL(string: "https://tinyfoodtour.com/u/\(handle)") {
                ShareLink(
                    item: url,
                    subject: Text("\(profile.displayName.isEmpty ? handle : profile.displayName) on Tiny Food Tour"),
                    message: Text("tinyfoodtour.com/u/\(handle)")
                ) {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up").scaledFont(size: 12)
                        Text("Share profile").scaledFont(size: 13)
                    }
                    .foregroundColor(Color("Primary"))
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 20)
        .background(Color("PizzaCrust"))
    }

    private func badgesSection(_ profile: PublicProfile) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BADGES")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(Color("SlateMid"))
                .tracking(1.5)
                .padding(.horizontal, 20)
                .padding(.top, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(vm.badges) { badge in
                        BadgePill(badge: badge)
                    }
                    // Show "next" badge as locked
                    if let next = BadgesService.nextUnearned(completedCount: profile.completedToursCount) {
                        BadgePill(badge: next, locked: true)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
    }

    private var toursSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TOURS")
                .scaledFont(size: 11, weight: .semibold)
                .foregroundColor(Color("SlateMid"))
                .tracking(1.5)
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 8)

            ForEach(vm.publishedTours) { tour in
                Button { vm.selectedTour = tour } label: {
                    PublishedTourRow(tour: tour)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notFoundView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.slash")
                .font(.system(size: 40)).foregroundColor(Color("SlateMid"))
            Text("Profile not found")
                .font(TFTFont.heading(20)).foregroundColor(Color("Foreground"))
            Text("@\(handle) isn't a public profile.")
                .scaledFont(size: 14).foregroundColor(Color("SlateMid"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 80)
    }

    private var emptyToursView: some View {
        Text("No published tours yet.")
            .scaledFont(size: 14).foregroundColor(Color("SlateMid"))
            .frame(maxWidth: .infinity).padding(.vertical, 32)
    }
}

// MARK: - Badge pill

struct BadgePill: View {
    let badge: Badge
    var locked: Bool = false

    var body: some View {
        VStack(spacing: 6) {
            Text(locked ? "🔒" : badge.emoji)
                .font(.system(size: 24))
                .opacity(locked ? 0.4 : 1)
            Text(locked ? "???" : badge.title)
                .scaledFont(size: 10, weight: .medium)
                .foregroundColor(locked ? Color("SlateMid").opacity(0.5) : Color("TFTSlate"))
                .multilineTextAlignment(.center)
        }
        .frame(width: 68)
        .padding(.vertical, 10)
        .background(locked ? Color("CreamDark").opacity(0.4) : Color("CreamDark"))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(locked ? 0.06 : 0.10), lineWidth: 1)
        )
    }
}

// MARK: - Published tour row

private struct PublishedTourRow: View {
    let tour: Tour

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tour.displayTitle)
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(Color("Foreground"))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(tour.neighborhood)
                    Text("·").foregroundColor(Color("SlateMid").opacity(0.5))
                    Text("\(tour.stops.count) stops")
                }
                .scaledFont(size: 12).foregroundColor(Color("SlateMid"))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .scaledFont(size: 12).foregroundColor(Color("SlateMid").opacity(0.5))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        Divider().padding(.leading, 20)
    }
}
