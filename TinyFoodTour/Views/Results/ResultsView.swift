import SwiftUI
import MapKit

struct ResultsView: View {
    let tour: Tour
    let isShared: Bool
    let generationParams: QuizAnswers?

    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var savedToursVM = SavedToursViewModel()
    @State private var navigateToLive = false
    @State private var isSaved = false
    @State private var showMap = false

    private var stopCount: Int { tour.stops.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    BrandMarkView()
                        .padding(.bottom, 4)

                    Text(tour.neighborhood)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.primary)

                    HStack(spacing: 8) {
                        ForEach(tour.vibe.prefix(2), id: \.self) { tag in
                            TagChip(text: tag)
                        }
                        TagChip(text: "\(stopCount) stops")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)

                // Map thumbnail
                TourMapView(stops: tour.stops)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)

                // Stops
                ForEach(Array(tour.stops.enumerated()), id: \.element.place_id) { index, stop in
                    StopCard(stop: stop, index: index, total: stopCount)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }

                // Action buttons
                VStack(spacing: 12) {
                    if !isShared {
                        CTAButton(title: "Start the Tour →", isEnabled: true) {
                            navigateToLive = true
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            savedToursVM.saveTour(token: tour.share_token)
                            isSaved = true
                        } label: {
                            Label(isSaved ? "Saved!" : "Save Tour", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 14))
                                .foregroundColor(isSaved ? Color("Radish") : .secondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .darkStatusBar()
        .navigationDestination(isPresented: $navigateToLive) {
            LiveTourView(tourId: tour.id)
                .environmentObject(authVM)
        }
    }
}

struct TagChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(.secondarySystemBackground))
            .clipShape(Capsule())
    }
}

struct StopCard: View {
    let stop: TourStop
    let index: Int
    let total: Int

    var stopColor: Color { StopLabel.color(index: index) }
    var label: String { StopLabel.label(index: index, total: total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(stopColor)
                        .kerning(1.2)

                    Text(stop.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text([stop.cuisine_type, stop.price_level.map { String(repeating: "$", count: max(1, $0)) }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let walkTime = stop.walk_time_from_previous, walkTime != "Starting point" {
                    HStack(spacing: 3) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 11))
                        Text(walkTime)
                            .font(.system(size: 11))
                    }
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
                }
            }

            if let desc = stop.description {
                Text(desc)
                    .font(.system(size: 14))
                    .foregroundColor(.primary.opacity(0.8))
                    .lineSpacing(3)
            }

            if let addr = stop.address {
                Text(addr)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                if let websiteUrl = stop.website_url, !websiteUrl.isEmpty, let url = URL(string: websiteUrl) {
                    Link(destination: url) {
                        Label("Website", systemImage: "safari")
                            .font(.system(size: 12))
                            .foregroundColor(Color("Radish"))
                    }
                }
                if let mapsUrl = stop.google_maps_url ?? googleMapsURL(for: stop),
                   let url = URL(string: mapsUrl) {
                    Link(destination: url) {
                        Label("Directions", systemImage: "map")
                            .font(.system(size: 12))
                            .foregroundColor(Color("Radish"))
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(stopColor.opacity(0.3), lineWidth: 1)
        )
    }

    private func googleMapsURL(for stop: TourStop) -> String? {
        let q = (stop.name + " " + (stop.address ?? ""))
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://maps.google.com/?q=\(q)"
    }
}

// MARK: - Map
struct TourMapView: View {
    let stops: [TourStop]

    @State private var region: MKCoordinateRegion

    init(stops: [TourStop]) {
        self.stops = stops
        let locatedStops = stops.filter { $0.lat != nil && $0.lng != nil }
        let center: CLLocationCoordinate2D
        if locatedStops.isEmpty {
            center = CLLocationCoordinate2D(latitude: 47.6, longitude: -122.33)
        } else {
            center = CLLocationCoordinate2D(
                latitude: locatedStops.map { $0.lat! }.reduce(0, +) / Double(locatedStops.count),
                longitude: locatedStops.map { $0.lng! }.reduce(0, +) / Double(locatedStops.count)
            )
        }
        _region = State(initialValue: MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
        ))
    }

    var body: some View {
        let locatedStops = stops.filter { $0.lat != nil && $0.lng != nil }
        Map(position: .constant(.region(region))) {
            ForEach(locatedStops) { stop in
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: stop.lat!, longitude: stop.lng!)) {
                    Circle()
                        .fill(StopLabel.color(index: (stop.stop_number - 1), total: stops.count))
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                }
            }
        }
    }
}

extension StopLabel {
    static func color(index: Int, total: Int) -> Color {
        color(index: index)
    }
}

#Preview {
    NavigationStack {
        ResultsView(tour: .preview, isShared: false, generationParams: nil)
            .environmentObject(AuthViewModel())
    }
}

extension Tour {
    static var preview: Tour {
        Tour(
            id: "preview", neighborhood: "Capitol Hill",
            vibe: ["Date night"], dietary: ["Eat everything"],
            walk_distance: "A short stroll (10 min)",
            stops: [
                TourStop(stop_number: 1, stop_type: "appetizer", place_id: "1",
                         name: "Stateside", address: "300 E Pike St", lat: 47.6142, lng: -122.3264,
                         cuisine_type: "Vietnamese", cuisine_label: nil, price_level: 2,
                         website_url: "", menu_url: nil, google_maps_url: nil,
                         description: "Crispy spring rolls with fish sauce caramel.", walk_time_from_previous: "Starting point",
                         rating: 4.5, photos: nil, opening_hours: nil),
                TourStop(stop_number: 2, stop_type: "main", place_id: "2",
                         name: "Altura", address: "617 Broadway E", lat: 47.6252, lng: -122.3209,
                         cuisine_type: "Italian", cuisine_label: nil, price_level: 4,
                         website_url: "", menu_url: nil, google_maps_url: nil,
                         description: "Multi-course Italian love letter to the Pacific Northwest.", walk_time_from_previous: "6 min walk",
                         rating: 4.8, photos: nil, opening_hours: nil),
                TourStop(stop_number: 3, stop_type: "dessert", place_id: "3",
                         name: "Molly Moon's", address: "917 E Pine St", lat: 47.6155, lng: -122.3198,
                         cuisine_type: "Ice Cream", cuisine_label: nil, price_level: 1,
                         website_url: "", menu_url: nil, google_maps_url: nil,
                         description: "Salted caramel is the move.", walk_time_from_previous: "4 min walk",
                         rating: 4.6, photos: nil, opening_hours: nil),
            ],
            created_at: Date().ISO8601Format(), user_id: nil, share_token: "preview"
        )
    }
}
