import SwiftUI
import MapKit

// MARK: - RouteSnapshotView
// Static MKMapSnapshotter image — no gesture conflict with ScrollView.
// Used on Results screen and as the "full route" view in Live Tour.
struct RouteSnapshotView: View {
    let stops: [TourStop]
    var highlightedIndex: Int? = nil   // Live Tour: marks current stop larger
    @State private var snapshot: UIImage?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let img = snapshot {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Color("CreamDark")
                if isLoading {
                    ProgressView().tint(Color("SlateMid"))
                }
            }
        }
        .task(id: stops.map(\.place_id).joined()) {
            await render()
        }
    }

    private func render() async {
        let located = stops.filter { $0.lat != nil && $0.lng != nil }
        guard !located.isEmpty else { isLoading = false; return }

        let options = MKMapSnapshotter.Options()
        // Render at 2× the display size for crisp retina
        let scale: CGFloat = UIScreen.main.scale
        options.size = CGSize(width: 700, height: 280)
        options.scale = scale
        options.mapType = .standard

        // Fit region to stops, matching web's fitBounds approach
        let lats = located.map { $0.lat! }
        let lngs = located.map { $0.lng! }
        let latSpan = max(0.006, (lats.max()! - lats.min()!) * 1.6)
        let lngSpan = max(0.006, (lngs.max()! - lngs.min()!) * 1.6)
        let center  = CLLocationCoordinate2D(
            latitude:  (lats.min()! + lats.max()!) / 2,
            longitude: (lngs.min()! + lngs.max()!) / 2
        )
        options.region = MKCoordinateRegion(
            center: center,
            span:   MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        )

        guard let snap = try? await MKMapSnapshotter(options: options).start() else {
            isLoading = false; return
        }

        // Draw markers on the snapshot image
        let size = options.size
        let rendered = UIGraphicsImageRenderer(size: size, format: {
            let f = UIGraphicsImageRendererFormat()
            f.scale = scale
            return f
        }()).image { _ in
            snap.image.draw(at: .zero)
            drawMarkers(snap: snap, stops: located, size: size)
        }
        await MainActor.run {
            snapshot = rendered
            isLoading = false
        }
    }

    private func drawMarkers(snap: MKMapSnapshotter.Snapshot, stops: [TourStop], size: CGSize) {
        let stopColors: [UIColor] = [
            UIColor(red: 0.769, green: 0.020, blue: 0.020, alpha: 1), // #c40505
            UIColor(red: 0.400, green: 0.392, blue: 0.161, alpha: 1), // #666429
            UIColor(red: 0.329, green: 0.012, blue: 0.012, alpha: 1), // #540303
            UIColor(red: 0.588, green: 0.710, blue: 0.086, alpha: 1), // #96b516
            UIColor(red: 0.608, green: 0.098, blue: 0.239, alpha: 1), // #9b193d
        ]

        for (i, stop) in stops.enumerated() {
            let pt = snap.point(for: CLLocationCoordinate2D(latitude: stop.lat!, longitude: stop.lng!))
            guard CGRect(origin: .zero, size: size).contains(pt) else { continue }

            let isCurrent = highlightedIndex == i
            let radius: CGFloat = isCurrent ? 14 : 11
            let color = stopColors[i % stopColors.count]

            // White ring
            let ringRect = CGRect(x: pt.x - radius - 2, y: pt.y - radius - 2,
                                  width: (radius + 2) * 2, height: (radius + 2) * 2)
            UIColor.white.setFill()
            UIBezierPath(ovalIn: ringRect).fill()

            // Coloured fill
            let dotRect = CGRect(x: pt.x - radius, y: pt.y - radius,
                                 width: radius * 2, height: radius * 2)
            color.setFill()
            UIBezierPath(ovalIn: dotRect).fill()

            // Number label
            let label = String(format: "%02d", i + 1)
            let fontSize: CGFloat = isCurrent ? 10 : 8
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let textSize = (label as NSString).size(withAttributes: attrs)
            let textRect = CGRect(
                x: pt.x - textSize.width / 2,
                y: pt.y - textSize.height / 2,
                width: textSize.width, height: textSize.height
            )
            (label as NSString).draw(in: textRect, withAttributes: attrs)
        }
    }
}

// MARK: - TourMapView (kept as alias for backward compat)
typealias TourMapView = RouteSnapshotView

// MARK: - MiniMapView (single-stop map in Live Tour, non-interactive)
struct MiniMapView: View {
    let stop: TourStop
    let allStops: [TourStop]
    let currentIndex: Int

    @State private var region: MKCoordinateRegion

    init(stop: TourStop, allStops: [TourStop], currentIndex: Int) {
        self.stop = stop
        self.allStops = allStops
        self.currentIndex = currentIndex
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: stop.lat ?? 47.6,
                longitude: stop.lng ?? -122.33
            ),
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        ))
    }

    var body: some View {
        RouteSnapshotView(stops: allStops, highlightedIndex: currentIndex)
    }
}
