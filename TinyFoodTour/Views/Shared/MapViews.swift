import SwiftUI
import MapKit

// MARK: - RouteSnapshotView
// Static MKMapSnapshotter image — no gesture conflict with ScrollView.
// Used on Results screen and as the "full route" view in Live Tour.
struct RouteSnapshotView: View {
    let stops: [TourStop]
    var highlightedIndex: Int? = nil       // Live Tour: current stop (larger)
    var completedIndices: Set<Int> = []    // Live Tour: draw ✓ on completed
    @State private var snapshot: UIImage?
    @State private var isLoading = true

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let img = snapshot {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    Color("CreamDark")
                    if isLoading {
                        ProgressView().tint(Color("SlateMid"))
                    }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .task(id: stops.map(\.place_id).joined() + "\(geo.size.width)-\(completedIndices.sorted().map(String.init).joined())") {
                await render(width: geo.size.width, height: geo.size.height)
            }
        }
    }

    private func render(width: CGFloat, height: CGFloat) async {
        guard width > 0, height > 0 else { return }
        let located = stops.filter { $0.lat != nil && $0.lng != nil }
        guard !located.isEmpty else { isLoading = false; return }

        let scale = UIScreen.main.scale
        let options = MKMapSnapshotter.Options()
        options.size = CGSize(width: width, height: height)
        options.scale = scale
        options.mapType = .standard

        // Fit region to all stops with padding — mirrors web fitBounds
        let lats = located.map { $0.lat! }
        let lngs = located.map { $0.lng! }
        let spread = (
            lat: lats.max()! - lats.min()!,
            lng: lngs.max()! - lngs.min()!
        )
        // Single stop: show ~400m radius. Multi-stop: fit with 70% padding.
        let latSpan = spread.lat < 0.001 ? 0.008 : spread.lat * 1.7
        let lngSpan = spread.lng < 0.001 ? 0.008 : spread.lng * 1.7
        options.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude:  (lats.min()! + lats.max()!) / 2,
                longitude: (lngs.min()! + lngs.max()!) / 2
            ),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        )

        guard let snap = try? await MKMapSnapshotter(options: options).start() else {
            isLoading = false; return
        }

        let renderSize = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let rendered = UIGraphicsImageRenderer(size: renderSize, format: format).image { _ in
            snap.image.draw(at: .zero)
            drawRoute(snap: snap, stops: located, size: renderSize)
        }
        await MainActor.run { snapshot = rendered; isLoading = false }
    }

    // Draws dashed burgundy polyline then numbered markers — matches web TourMap
    private func drawRoute(snap: MKMapSnapshotter.Snapshot, stops: [TourStop], size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        let points = stops.compactMap { stop -> CGPoint? in
            guard stop.lat != nil, stop.lng != nil else { return nil }
            let pt = snap.point(for: CLLocationCoordinate2D(latitude: stop.lat!, longitude: stop.lng!))
            return bounds.contains(pt) ? pt : nil
        }

        // Dashed polyline — color #9b193d, matching web's burgundy route
        if points.count > 1 {
            let path = UIBezierPath()
            path.move(to: points[0])
            for pt in points.dropFirst() { path.addLine(to: pt) }
            path.lineWidth = 2.5
            path.setLineDash([6, 5], count: 2, phase: 0)
            UIColor(red: 0.608, green: 0.098, blue: 0.239, alpha: 0.8).setStroke()
            path.stroke()
        }

        // Numbered circle markers
        let stopColors: [UIColor] = [
            UIColor(red: 0.769, green: 0.020, blue: 0.020, alpha: 1),
            UIColor(red: 0.400, green: 0.392, blue: 0.161, alpha: 1),
            UIColor(red: 0.329, green: 0.012, blue: 0.012, alpha: 1),
            UIColor(red: 0.588, green: 0.710, blue: 0.086, alpha: 1),
            UIColor(red: 0.608, green: 0.098, blue: 0.239, alpha: 1),
        ]
        for (i, pt) in points.enumerated() {
            let isCurrent = highlightedIndex == i
            let isCompleted = completedIndices.contains(i)
            let r: CGFloat = isCurrent ? 13 : 10

            // White border ring
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(x: pt.x-r-2, y: pt.y-r-2, width: (r+2)*2, height: (r+2)*2)).fill()

            // Fill: green for completed, brand color otherwise
            let fillColor = isCompleted
                ? UIColor(red: 0.133, green: 0.773, blue: 0.369, alpha: 1)  // #22C55E green
                : stopColors[i % stopColors.count]
            fillColor.setFill()
            UIBezierPath(ovalIn: CGRect(x: pt.x-r, y: pt.y-r, width: r*2, height: r*2)).fill()

            // Label: ✓ for completed, zero-padded number otherwise
            let label = isCompleted ? "✓" : String(format: "%02d", i + 1)
            let fs: CGFloat = isCompleted ? (isCurrent ? 12 : 9) : (isCurrent ? 10 : 8)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fs, weight: .bold),
                .foregroundColor: UIColor.white
            ]
            let ts = (label as NSString).size(withAttributes: attrs)
            (label as NSString).draw(
                in: CGRect(x: pt.x-ts.width/2, y: pt.y-ts.height/2, width: ts.width, height: ts.height),
                withAttributes: attrs
            )
        }
    }
}

// MARK: - TourMapView alias
typealias TourMapView = RouteSnapshotView

// MARK: - MiniMapView (full route in Live Tour)
struct MiniMapView: View {
    let stop: TourStop
    let allStops: [TourStop]
    let currentIndex: Int
    var completedIndices: Set<Int> = []

    var body: some View {
        RouteSnapshotView(
            stops: allStops,
            highlightedIndex: currentIndex,
            completedIndices: completedIndices
        )
    }
}
