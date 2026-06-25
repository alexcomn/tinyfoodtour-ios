
import SwiftUI
import UIKit
import MapKit

// MARK: - TourCompleteView
// Full-screen burgundy celebration shown inline (ZStack overlay in LiveTourView)
// when the user completes all stops on their tour.

struct TourCompleteView: View {
    let tour: Tour
    let progress: [StopProgress]
    var onBuildAnother: (() -> Void)? = nil
    /// Returns the set of completed indices and the full progress array so
    /// ResultsView can render user photos + notes on the stop cards.
    var onLookAtStops: ((Set<Int>, [StopProgress]) -> Void)? = nil

    @State private var shareImage: UIImage?     = nil
    @State private var isRenderingShare         = false
    @State private var isSharePresented         = false

    var body: some View {
        ZStack {
            Color("Primary").ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        headerSection
                        stopZigzag
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 64)
                    .padding(.bottom, 20)
                }

                bottomButtons
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .padding(.bottom, max(16, UIApplication.safeAreaBottom))
                    .background(Color("Primary"))
            }
        }
        .sheet(isPresented: $isSharePresented) {
            if let img = shareImage {
                let shareURL = URL(string: "tinyfoodtour://tour/\(tour.share_token)")
                ShareSheet(items: shareURL.map { [img, $0] } ?? [img])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            BrandMarkView(fontSize: 15, color: .white)
                .opacity(0.85)

            Text("You completed today's\nTiNY FOOD TOUR!")
                .font(TFTFont.heading(28))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Text("Every stop in \(tour.neighborhood), on foot.")
                .scaledFont(size: 14)
                .foregroundColor(.white.opacity(0.70))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Zigzag stop list

    private var stopZigzag: some View {
        VStack(spacing: 0) {
            ForEach(Array(tour.stops.enumerated()), id: \.offset) { i, stop in
                let label = StopLabel.label(
                    index: i, total: tour.stops.count,
                    mealType: tour.mealType, vibes: tour.vibe
                )
                let isLeft = i % 2 == 0

                VStack(spacing: 0) {
                    stopRow(stop: stop, label: label, circleLeft: isLeft)

                    if i < tour.stops.count - 1 {
                        connectorLine(fromLeft: isLeft)
                            .frame(height: 34)
                            .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    private func stopRow(stop: TourStop, label: String, circleLeft: Bool) -> some View {
        HStack(alignment: .center, spacing: 14) {
            if circleLeft {
                stopCircle
                VStack(alignment: .leading, spacing: 3) {
                    Text(stop.name)
                        .font(TFTFont.heading(16))
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(label)
                        .scaledFont(size: 9, weight: .semibold)
                        .foregroundColor(.white.opacity(0.60))
                        .tracking(1.8)
                }
                Spacer()
            } else {
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(stop.name)
                        .font(TFTFont.heading(16))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(label)
                        .scaledFont(size: 9, weight: .semibold)
                        .foregroundColor(.white.opacity(0.60))
                        .tracking(1.8)
                }
                stopCircle
            }
        }
    }

    private var stopCircle: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.15))
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5))
            Image(systemName: "checkmark")
                .scaledFont(size: 13, weight: .heavy)
                .foregroundColor(.white)
        }
        .frame(width: 50, height: 50)
    }

    private func connectorLine(fromLeft: Bool) -> some View {
        Canvas { ctx, size in
            var path = Path()
            let startX = fromLeft ? size.width * 0.12 : size.width * 0.88
            let endX   = fromLeft ? size.width * 0.88 : size.width * 0.12
            path.move(to: CGPoint(x: startX, y: 0))
            path.addLine(to: CGPoint(x: endX, y: size.height))
            ctx.stroke(path, with: .color(.white.opacity(0.30)),
                       style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
    }

    // MARK: - Bottom buttons

    private var bottomButtons: some View {
        VStack(spacing: 14) {
            // Primary: share
            Button {
                Task { await generateAndShare() }
            } label: {
                HStack(spacing: 8) {
                    if isRenderingShare {
                        ProgressView()
                            .tint(Color("Primary"))
                            .scaleEffect(0.85)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                            .scaledFont(size: 15)
                    }
                    Text(isRenderingShare ? "Creating…" : "Share your tour")
                        .scaledFont(size: 15, weight: .semibold)
                }
                .foregroundColor(Color("Primary"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isRenderingShare)

            // Secondary: review stops in Results screen
            Button {
                let completed = Set(progress.indices.filter { progress[$0].completed })
                onLookAtStops?(completed, progress)
            } label: {
                Text("Look at my stops")
                    .scaledFont(size: 15)
                    .foregroundColor(.white.opacity(0.85))
            }
            .buttonStyle(.plain)

            // Tertiary: build another tour
            Button {
                onBuildAnother?()
            } label: {
                Text("Build another tour →")
                    .scaledFont(size: 14)
                    .foregroundColor(.white.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Share card rendering

    @MainActor
    private func generateAndShare() async {
        isRenderingShare = true
        // Pre-render the route map synchronously before ImageRenderer runs —
        // ImageRenderer is synchronous and won't wait for async MKMapSnapshotter.
        let mapImg = await renderRouteMapImage()
        let cardView = TourShareCardView(tour: tour, progress: progress, mapImage: mapImg)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        shareImage = renderer.uiImage
        isRenderingShare = false
        isSharePresented = true
    }

    private func renderRouteMapImage() async -> UIImage? {
        let cardWidth: CGFloat = 390
        let mapHeight: CGFloat = 160
        let stops = tour.stops
        guard !stops.isEmpty else { return nil }
        guard let region = RouteMapFraming.fitRegion(
            stops: stops, aspect: cardWidth / mapHeight
        ) else { return nil }

        let options = MKMapSnapshotter.Options()
        options.size = CGSize(width: cardWidth, height: mapHeight)
        options.scale = 3
        options.mapType = .standard
        options.region = region
        guard let snap = try? await MKMapSnapshotter(options: options).start() else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        return UIGraphicsImageRenderer(
            size: CGSize(width: cardWidth, height: mapHeight), format: format
        ).image { _ in
            snap.image.draw(at: .zero)
            let bounds = CGRect(origin: .zero, size: CGSize(width: cardWidth, height: mapHeight))
            let points = stops.compactMap { s -> CGPoint? in
                guard let lat = s.lat, let lng = s.lng else { return nil }
                let pt = snap.point(for: CLLocationCoordinate2D(latitude: lat, longitude: lng))
                return bounds.contains(pt) ? pt : nil
            }
            if points.count > 1 {
                let path = UIBezierPath()
                path.move(to: points[0])
                for pt in points.dropFirst() { path.addLine(to: pt) }
                path.lineWidth = 2.5
                path.setLineDash([6, 5], count: 2, phase: 0)
                UIColor(red: 0.608, green: 0.098, blue: 0.239, alpha: 0.9).setStroke()
                path.stroke()
            }
            for (i, pt) in points.enumerated() {
                let r: CGFloat = 11
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(x: pt.x-r-2, y: pt.y-r-2, width: (r+2)*2, height: (r+2)*2)).fill()
                UIColor(red: 0.608, green: 0.098, blue: 0.239, alpha: 1).setFill()
                UIBezierPath(ovalIn: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)).fill()
                let label = String(format: "%02d", i + 1) as NSString
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let ts = label.size(withAttributes: attrs)
                label.draw(
                    in: CGRect(x: pt.x-ts.width/2, y: pt.y-ts.height/2, width: ts.width, height: ts.height),
                    withAttributes: attrs
                )
            }
        }
    }
}

// MARK: - TourShareCardView
// Rendered offscreen via ImageRenderer → UIImage for the share sheet.
// Uses only statically-available content (no AsyncImage) so ImageRenderer
// captures a complete image synchronously.

struct TourShareCardView: View {
    let tour: Tour
    let progress: [StopProgress]
    var mapImage: UIImage? = nil

    private let cardWidth: CGFloat  = 390
    private let cardHeight: CGFloat = 870   // header + map + stops

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .long
        return fmt.string(from: Date())
    }

    var body: some View {
        ZStack {
            Color("Primary")

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────────────
                VStack(spacing: 8) {
                    BrandMarkView(fontSize: 16, color: .white)
                        .opacity(0.85)
                        .padding(.top, 52)

                    Text("Tour Complete 🎉")
                        .font(TFTFont.heading(30))
                        .foregroundColor(.white)

                    Text("Every stop in \(tour.neighborhood), on foot.")
                        .scaledFont(size: 13)
                        .foregroundColor(.white.opacity(0.70))
                }
                .padding(.bottom, 24)

                // ── Tour title ──────────────────────────────────────────────
                VStack(spacing: 4) {
                    Text(tour.displayTitle)
                        .font(TFTFont.heading(20))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("\(tour.stops.count) stops · \(tour.neighborhood)")
                        .scaledFont(size: 12)
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)

                // ── Divider ────────────────────────────────────────────────
                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(height: 1)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)

                // ── Route map ──────────────────────────────────────────────
                if let img = mapImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth - 56, height: 160)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal, 28)
                        .padding(.bottom, 18)
                }

                // ── Stop list ──────────────────────────────────────────────
                VStack(spacing: 14) {
                    ForEach(Array(tour.stops.enumerated()), id: \.offset) { i, stop in
                        let label = StopLabel.label(
                            index: i, total: tour.stops.count,
                            mealType: tour.mealType, vibes: tour.vibe
                        )
                        HStack(spacing: 14) {
                            // Numbered circle
                            ZStack {
                                Circle()
                                    .fill(.white.opacity(0.15))
                                    .overlay(
                                        Circle().strokeBorder(.white.opacity(0.35), lineWidth: 1.5)
                                    )
                                Text(String(format: "%02d", i + 1))
                                    .scaledFont(size: 12, weight: .bold)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 40, height: 40)

                            // Label + name
                            VStack(alignment: .leading, spacing: 2) {
                                Text(label)
                                    .scaledFont(size: 9, weight: .semibold)
                                    .foregroundColor(.white.opacity(0.55))
                                    .tracking(1.5)
                                Text(stop.name)
                                    .font(TFTFont.heading(15))
                                    .foregroundColor(.white)
                            }

                            Spacer()

                            // Checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .scaledFont(size: 18)
                                .foregroundColor(.white.opacity(0.65))
                        }
                    }
                }
                .padding(.horizontal, 28)

                Spacer()

                // ── Footer ─────────────────────────────────────────────────
                VStack(spacing: 4) {
                    Text(dateString)
                        .scaledFont(size: 11)
                        .foregroundColor(.white.opacity(0.45))
                    Text("tinyfoodtour.com")
                        .scaledFont(size: 11, weight: .medium)
                        .foregroundColor(.white.opacity(0.55))
                }
                .padding(.bottom, 36)
            }
        }
        .frame(width: cardWidth, height: cardHeight)
    }
}

// MARK: - ShareSheet
// Thin UIViewControllerRepresentable wrapper around UIActivityViewController.

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController,
                                context: Context) {}
}

// MARK: - Preview

#Preview("Tour Complete") {
    let stops: [TourStop] = [
        TourStop(
            stop_number: 1, stop_type: "appetizer",
            place_id: "p1", name: "The Pioneer Café",
            address: "3601 Fremont Ave N, Seattle",
            lat: 47.6505, lng: -122.3504,
            cuisine_type: "Cafe", cuisine_label: "Artisan Espresso Bar",
            price_level: 2, website_url: nil, menu_url: nil, google_maps_url: nil,
            description: "Your first sip of Fremont is the best sip.",
            walk_time_from_previous: "Starting point",
            rating: 4.6, photos: nil, opening_hours: nil
        ),
        TourStop(
            stop_number: 2, stop_type: "main",
            place_id: "p2", name: "Fremont Bowl",
            address: "4307 Fremont Ave N, Seattle",
            lat: 47.6512, lng: -122.3483,
            cuisine_type: "Japanese", cuisine_label: "Cozy Ramen Den",
            price_level: 2, website_url: nil, menu_url: nil, google_maps_url: nil,
            description: "Rich tonkotsu broth so good.",
            walk_time_from_previous: "8 min walk",
            rating: 4.4, photos: nil, opening_hours: nil
        ),
        TourStop(
            stop_number: 3, stop_type: "dessert",
            place_id: "p3", name: "Molly Moon's Homemade Ice Cream",
            address: "1622 N 45th St, Seattle",
            lat: 47.6619, lng: -122.3469,
            cuisine_type: "Ice Cream", cuisine_label: "Farm-to-Cone Creamery",
            price_level: 1, website_url: nil, menu_url: nil, google_maps_url: nil,
            description: "Honey lavender will ruin every other ice cream forever.",
            walk_time_from_previous: "6 min walk",
            rating: 4.8, photos: nil, opening_hours: nil
        ),
    ]

    let sampleProgress: [StopProgress] = stops.map { _ in
        var p = StopProgress(); p.completed = true; return p
    }

    let tour = Tour(
        id: "preview", neighborhood: "Fremont",
        vibe: [], dietary: [],
        walk_distance: "Short stroll", stops: stops,
        created_at: "2025-01-01T00:00:00Z", user_id: nil,
        share_token: "preview-token",
        tourTitle: "Fremont Flavor Trail",
        totalDistanceMiles: 0.8
    )

    TourCompleteView(tour: tour, progress: sampleProgress)
}
