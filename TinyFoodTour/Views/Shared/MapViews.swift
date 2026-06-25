import SwiftUI
import MapKit

// MARK: - RouteMapFraming
// Shared camera-fitting math used by both the static MKMapSnapshotter preview
// (RouteSnapshotView) and the interactive full-screen Map (InteractiveRouteMapView)
// so the route is framed identically everywhere it appears.
enum RouteMapFraming {
    /// Route occupies ~87% of the frame, leaving a ~6.5% margin per side —
    /// enough to clear marker radii without leaving the route looking distant.
    static let defaultPadding: Double = 1.15

    /// Computes a region that fits all located stops to the given frame
    /// aspect ratio (width / height), padded so the route nearly fills it.
    static func fitRegion(stops: [TourStop], aspect: CGFloat, padding: Double = defaultPadding) -> MKCoordinateRegion? {
        let located = stops.filter { $0.lat != nil && $0.lng != nil }
        guard !located.isEmpty else { return nil }

        let lats = located.map { $0.lat! }
        let lngs = located.map { $0.lng! }
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLng = (lngs.min()! + lngs.max()!) / 2

        // Raw geographic extent, floored so a single/clustered tour gets a
        // sensible neighbourhood-level view instead of zooming to max.
        let rawLat = max(lats.max()! - lats.min()!, 0.0025)   // ~275m
        let rawLng = max(lngs.max()! - lngs.min()!, 0.0025)

        let padLat = rawLat * padding
        let padLng = rawLng * padding

        // Longitude degrees are compressed by cos(latitude); fold that in so the
        // on-screen aspect comparison is in real screen-space terms.
        let cosLat = max(cos(centerLat * .pi / 180), 0.01)
        let frameAspect = max(aspect, 0.01)
        let boxAspect = (padLng * cosLat) / padLat

        let latSpan: CLLocationDegrees
        let lngSpan: CLLocationDegrees
        if boxAspect > frameAspect {
            // Route is wider than the frame → width-bound; expand latitude.
            lngSpan = padLng
            latSpan = (padLng * cosLat) / frameAspect
        } else {
            // Route is taller/narrower than the frame → height-bound; expand longitude.
            latSpan = padLat
            lngSpan = (padLat * frameAspect) / cosLat
        }

        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLng),
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lngSpan)
        )
    }
}

// MARK: - RouteSnapshotView
// Static MKMapSnapshotter image — no gesture conflict with ScrollView.
// Used on Results screen and as the "full route" view in Live Tour.
// Tapping it opens InteractiveRouteMapView (a real, pinch/rotate-able Map)
// in a sheet, framed identically via RouteMapFraming.
struct RouteSnapshotView: View {
    let stops: [TourStop]
    var highlightedIndex: Int? = nil       // Live Tour: current stop (larger)
    var completedIndices: Set<Int> = []    // Live Tour: draw ✓ on completed
    var height: CGFloat = 200              // shared default — keep Results & Live Tour in sync

    @State private var snapshot: UIImage?
    @State private var isLoading = true
    @State private var showFullMap = false

    // Fixed render dimensions — avoids GeometryReader inside ScrollView which
    // reports infinite height during measurement and collapses scroll content.
    // Map section has 20pt padding each side so usable width = screen - 40.
    private var renderWidth: CGFloat { UIScreen.main.bounds.width - 40 }

    private var located: [TourStop] { stops.filter { $0.lat != nil && $0.lng != nil } }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ZStack {
                if let img = snapshot {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: renderWidth, height: height)
                        .clipped()
                } else {
                    Color("CreamDark")
                    if isLoading {
                        ProgressView().tint(Color("SlateMid"))
                    }
                }
            }
            .frame(width: renderWidth, height: height)

            // Expand affordance — hints that the route can be opened full-screen
            // for pinch-to-zoom / rotate, per §2 of the maps redesign.
            if snapshot != nil && located.count > 1 {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .scaledFont(size: 11, weight: .semibold)
                    .foregroundColor(.white)
                    .padding(7)
                    .background(.black.opacity(0.35), in: Circle())
                    .padding(10)
            }
        }
        .frame(width: renderWidth, height: height)
        .contentShape(Rectangle())
        .onTapGesture {
            guard located.count > 1 else { return }
            showFullMap = true
        }
        // Include highlightedIndex/height in the task key so Live Tour
        // re-renders the map each time the user navigates to a different stop
        // (changes the marker emphasis) or the frame size changes.
        .task(id: stops.map(\.place_id).joined()
              + "-\(completedIndices.sorted().map(String.init).joined())"
              + "-\(highlightedIndex.map(String.init) ?? "all")"
              + "-\(Int(height))") {
            await render(width: renderWidth, height: height)
        }
        .sheet(isPresented: $showFullMap) {
            InteractiveRouteMapView(
                stops: stops,
                highlightedIndex: highlightedIndex,
                completedIndices: completedIndices
            )
        }
    }

    private func render(width: CGFloat, height: CGFloat) async {
        guard width > 0, height > 0 else { return }
        guard !located.isEmpty else { isLoading = false; return }

        let scale = UIScreen.main.scale
        let options = MKMapSnapshotter.Options()
        options.size = CGSize(width: width, height: height)
        options.scale = scale
        options.mapType = .standard

        // Always fit the full route, regardless of Live Tour vs Results — the
        // current stop is emphasized with a larger marker (see drawRoute), but
        // the camera always shows every stop for orientation/context. Shared
        // with InteractiveRouteMapView so the route appears in the same place
        // at the same zoom level everywhere.
        guard let region = RouteMapFraming.fitRegion(stops: stops, aspect: width / height) else {
            isLoading = false; return
        }
        options.region = region

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
                : UIColor(StopLabel.color(index: i))
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

// MARK: - InteractiveRouteMapView
// Real MapKit `Map` (iOS 17+) opened from RouteSnapshotView's tap — lets the
// user pinch-zoom, rotate, and pan the route. Initial camera uses the same
// RouteMapFraming.fitRegion() as the static snapshot, so the route appears in
// the same place/zoom as the preview it was opened from before the user
// starts interacting with it.
struct InteractiveRouteMapView: View {
    let stops: [TourStop]
    var highlightedIndex: Int? = nil
    var completedIndices: Set<Int> = []

    @Environment(\.dismiss) var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var located: [TourStop] { stops.filter { $0.lat != nil && $0.lng != nil } }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                Map(position: $cameraPosition, interactionModes: .all) {
                    if located.count > 1 {
                        MapPolyline(coordinates: located.map {
                            CLLocationCoordinate2D(latitude: $0.lat!, longitude: $0.lng!)
                        })
                        .stroke(Color(red: 0.608, green: 0.098, blue: 0.239).opacity(0.8),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [9, 7]))
                    }

                    ForEach(Array(located.enumerated()), id: \.element.place_id) { i, stop in
                        Annotation("", coordinate: CLLocationCoordinate2D(latitude: stop.lat!, longitude: stop.lng!)) {
                            routeMarker(index: i)
                        }
                    }
                }
                .mapStyle(.standard(pointsOfInterest: .excludingAll))
                .ignoresSafeArea(edges: .bottom)
                .onAppear {
                    let aspect = geo.size.width / max(geo.size.height, 1)
                    if let region = RouteMapFraming.fitRegion(stops: stops, aspect: aspect) {
                        cameraPosition = .region(region)
                    }
                }
            }
            .navigationTitle("Tour route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .scaledFont(size: 22)
                            .foregroundColor(Color("SlateMid").opacity(0.6))
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func routeMarker(index: Int) -> some View {
        let isCurrent = highlightedIndex == index
        let isCompleted = completedIndices.contains(index)
        let size: CGFloat = isCurrent ? 34 : 28

        ZStack {
            Circle()
                .fill(.white)
                .frame(width: size + 5, height: size + 5)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
            Circle()
                .fill(isCompleted ? Color(hex: "#22c55e") : StopLabel.color(index: index))
                .frame(width: size, height: size)
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: isCurrent ? 14 : 11, weight: .bold))
                    .foregroundColor(.white)
            } else {
                Text(String(format: "%02d", index + 1))
                    .font(.system(size: isCurrent ? 12 : 10, weight: .bold))
                    .foregroundColor(.white)
            }
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
    var height: CGFloat = 200

    var body: some View {
        RouteSnapshotView(
            stops: allStops,
            highlightedIndex: currentIndex,
            completedIndices: completedIndices,
            height: height
        )
    }
}
