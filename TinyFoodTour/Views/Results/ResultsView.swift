import SwiftUI
import MapKit

// MARK: - Results screen
// Design mirrors Results.tsx: pizza-crust header, white stop cards, circular color
// badge, serif headings, photo strips, today's hours, link buttons.

struct ResultsView: View {
    let tour: Tour
    let isShared: Bool
    let generationParams: QuizAnswers?

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var savedVM = SavedToursViewModel()
    @StateObject private var tweakVM = TourViewModel()
    @State private var navigateToLive = false
    @State private var isSaved = false
    @State private var currentTour: Tour
    @State private var shufflingIndex: Int? = nil
    @State private var showTweaks = false
    @State private var tweakStops: Double
    @State private var tweakPrice: Double

    init(tour: Tour, isShared: Bool, generationParams: QuizAnswers?) {
        self.tour = tour
        self.isShared = isShared
        self.generationParams = generationParams
        _currentTour = State(initialValue: tour)
        // Initialise sliders to current tour values
        let stopCount = max(2, min(5, tour.stops.count))
        _tweakStops = State(initialValue: Double(stopCount))
        _tweakPrice = State(initialValue: 3)
    }

    private var stops: [TourStop] { currentTour.stops }

    private var tourMetaLine: String {
        var parts = ["\(stops.count) stops"]
        if let miles = tour.totalDistanceMiles { parts.append(String(format: "~%.1f mi", miles)) }
        // Rough walking time from distance (or sum of individual walk times)
        let totalMins = stops.compactMap { s -> Int? in
            guard let walk = s.walk_time_from_previous else { return nil }
            let nums = walk.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap(Int.init)
            return nums.first
        }.reduce(0, +)
        if totalMins > 0 { parts.append("~\(totalMins) min walking") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        // No NavigationStack, no .toolbar, no .navigationBarTitleDisplayMode.
        // iOS 26 applies automatic content margin adjustments via those modifiers
        // that shift ScrollView content left. We own all navigation chrome manually.
        ScrollView(.vertical, showsIndicators: true) {
            VStack(spacing: 0) {
                header
                mapSection

                if stops.isEmpty {
                    emptyStopsView
                } else {
                    VStack(spacing: 12) {
                        ForEach(Array(stops.enumerated()), id: \.element.place_id) { idx, stop in
                            StopCard(
                                stop: stop,
                                tourId: currentTour.id,
                                index: idx,
                                total: stops.count,
                                vibes: currentTour.vibe,
                                isFirst: idx == 0,
                                isShuffling: shufflingIndex == idx,
                                onStartHere: { navigateToLive = true },
                                onShuffle: isShared ? nil : { Task { await shuffleStop(at: idx) } }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }

                actionBar
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color("Cream"))
        // safeAreaInset works correctly in a UIHostingController context (no iOS 26 SwiftUI
        // presentation offset). Places the nav buttons in the top safe area cleanly.
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color("TFTSlate"))
                        .frame(width: 38, height: 38)
                        .background(Color("Cream"))
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                }
                Spacer()
                if !isShared {
                    Button { showTweaks = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 15))
                            .foregroundColor(Color("TFTSlate"))
                            .frame(width: 38, height: 38)
                            .background(Color("Cream"))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color("Cream"))
        }
        .darkStatusBar()
        .sheet(isPresented: $showTweaks) { tweaksSheet }
        .onChange(of: tweakVM.tour) { _, newTour in
            if let t = newTour { currentTour = t; showTweaks = false }
        }
        .onReceive(NotificationCenter.default.publisher(for: .buildAnotherTour)) { _ in
            dismiss()
        }
        // LiveTour via UIKit .crossDissolve — consistent with Results presentation
        .uiFullScreen(isPresented: $navigateToLive) {
            LiveTourView(tourId: tour.id)
                .environmentObject(authVM)
        }
    }

    // MARK: - Header (bg-pizza-crust)
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandMarkView(fontSize: 15)
                .padding(.bottom, 12)

            Text(tour.displayTitle)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundColor(Color("Primary"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            // Plain dot-separated line — matches web "3 stops · ~0.4 mi · ~10 min walking"
            Text(tourMetaLine)
                .font(.system(size: 13))
                .foregroundColor(Color("SlateMid"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 20)
        .background(Color("Cream"))
    }

    // MARK: - Map
    private var mapSection: some View {
        VStack(spacing: 0) {
            // §6 brief: show "stretched tour" notice when relaxations includes "allowed_visited"
            if currentTour.relaxations.contains("allowed_visited") {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(Color("TFTOrange"))
                    Text("We stretched a bit — one of these is from a previous tour. Slim pickings in this corner of the map.")
                        .font(.system(size: 12))
                        .foregroundColor(Color("SlateMid"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            RouteSnapshotView(stops: stops)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
    }

    // MARK: - Stop cards
    // MARK: - Shuffle
    private func shuffleStop(at index: Int) async {
        guard shufflingIndex == nil else { return }
        shufflingIndex = index
        struct ShuffleResponse: Codable { let stop: TourStop? }
        do {
            let result: ShuffleResponse = try await SupabaseService.shared.invokeFunction(
                name: "shuffle-stop",
                body: ["tour_id": currentTour.id, "stop_index": index]
            )
            if let newStop = result.stop {
                var newStops = currentTour.stops
                newStops[index] = newStop
                currentTour = Tour(
                    id: currentTour.id, neighborhood: currentTour.neighborhood,
                    vibe: currentTour.vibe, dietary: currentTour.dietary,
                    walk_distance: currentTour.walk_distance, stops: newStops,
                    created_at: currentTour.created_at, user_id: currentTour.user_id,
                    share_token: currentTour.share_token,
                    tourTitle: currentTour.tourTitle,
                    totalDistanceMiles: currentTour.totalDistanceMiles
                )
            }
        } catch {
            // Shuffle failed silently — user can try again
        }
        shufflingIndex = nil
    }

    // MARK: - Tweaks sheet
    private var tweaksSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                // Stops slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Stops")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("Foreground"))
                        Spacer()
                        Text("\(Int(tweakStops))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("Primary"))
                    }
                    Slider(value: $tweakStops, in: 2...5, step: 1)
                        .tint(Color("Primary"))
                    HStack {
                        Text("2").font(.system(size: 11)).foregroundColor(Color("SlateMid"))
                        Spacer()
                        Text("5").font(.system(size: 11)).foregroundColor(Color("SlateMid"))
                    }
                }

                // Pricing slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Pricing")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color("Foreground"))
                        Spacer()
                        Text(String(repeating: "$", count: Int(tweakPrice)))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color("Primary"))
                    }
                    Slider(value: $tweakPrice, in: 1...4, step: 1)
                        .tint(Color("Primary"))
                    HStack {
                        Text("$").font(.system(size: 11)).foregroundColor(Color("SlateMid"))
                        Spacer()
                        Text("$$$$").font(.system(size: 11)).foregroundColor(Color("SlateMid"))
                    }
                }

                Spacer()

                // Apply
                if tweakVM.isGenerating {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color("Radish"))
                        Text(tweakVM.generatingMessage)
                            .font(.system(size: 13))
                            .foregroundColor(Color("Radish"))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    CTAButton(title: "Apply filters", isEnabled: true) {
                        guard var params = generationParams else { return }
                        params.walkDistance = params.walkDistance.isEmpty
                            ? "A short stroll (10 min)" : params.walkDistance
                        Task {
                            var tweakedParams = params
                            // Inject tweaked values — TourViewModel.generate() reads them
                            await tweakVM.generateWithTweaks(
                                answers: tweakedParams,
                                numStops: Int(tweakStops),
                                maxPrice: Int(tweakPrice)
                            )
                        }
                    }
                }
            }
            .padding(24)
            .navigationTitle("Tweak your tour")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { showTweaks = false }
                        .foregroundColor(Color("SlateMid"))
                }
            }
        }
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }

    private var emptyStopsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 40))
                .foregroundColor(Color("SlateMid"))
            Text("We couldn't find stops for this tour.")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Color("TFTSlate"))
            Text("Try a different neighborhood or adjust your preferences.")
                .font(.system(size: 13))
                .foregroundColor(Color("SlateMid"))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 48)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Bottom action bar
    private var actionBar: some View {
        VStack(spacing: 12) {
            if !isShared {
                Button {
                    navigateToLive = true
                } label: {
                    Text("Start my tour →")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("Primary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Share + Save row
                HStack(spacing: 16) {
                    // Save bookmark
                    Button {
                        savedVM.saveTour(token: currentTour.share_token)
                        isSaved = true
                    } label: {
                        Label(isSaved ? "Saved!" : "Save tour",
                              systemImage: isSaved ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14))
                            .foregroundColor(isSaved ? Color("Radish") : Color("SlateMid"))
                    }

                    Spacer()

                    // Native iOS share sheet — shares tinyfoodtour.com/tour/{token}
                    if let shareURL = URL(string: "https://tinyfoodtour.com/tour/\(currentTour.share_token)") {
                        ShareLink(
                            item: shareURL,
                            subject: Text(currentTour.displayTitle),
                            message: Text("Check out this food tour I built on Tiny Food Tour!")
                        ) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(Color("SlateMid"))
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
    }
}

// MARK: - Stop card
struct StopCard: View {
    @State private var showMenu = false
    let stop: TourStop
    let tourId: String           // for menu_items DB lookup
    let index: Int
    let total: Int
    let vibes: [String]
    let isFirst: Bool
    let isShuffling: Bool
    let onStartHere: () -> Void
    let onShuffle: (() -> Void)?

    private var stopColor: Color { StopLabel.color(index: index) }
    private var stopLabel: String { StopLabel.label(index: index, total: total, vibes: vibes) }

    // cuisine_label preferred; fall back to cleaned cuisine_type
    private var cuisineDisplay: String {
        if let label = stop.cuisine_label, !label.isEmpty { return label }
        if let type_ = stop.cuisine_type, !type_.isEmpty {
            return type_.replacingOccurrences(of: "_", with: " ")
                .capitalized
        }
        return "Restaurant"
    }

    private var priceDisplay: String {
        guard let p = stop.price_level, p > 0 else { return "" }
        return String(repeating: "$", count: p)
    }

    // Today's hours extracted from opening_hours array
    private var todaysHours: String? {
        guard let hours = stop.opening_hours, !hours.isEmpty else { return nil }
        let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        let today = days[Calendar.current.component(.weekday, from: Date()) - 1]
        guard let line = hours.first(where: { $0.hasPrefix(today) }) else { return nil }
        return line.replacingOccurrences(of: "\(today): ", with: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Row 1: badge · label+name · walk/start ──────────────────────
            HStack(alignment: .top, spacing: 12) {
                // Numbered circle badge
                ZStack {
                    Circle().fill(stopColor)
                    Text(String(format: "%02d", index + 1))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 30, height: 30)
                .flexibleShrink()

                // Label + name
                VStack(alignment: .leading, spacing: 2) {
                    Text(stopLabel)
                        .font(.system(size: 10, weight: .medium))
                        .kerning(1.5)
                        .foregroundColor(stopColor)

                    Text(stop.name)
                        .font(.system(size: 17, weight: .semibold, design: .serif))
                        .foregroundColor(Color("TFTSlate"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Shuffle + walk time / start here
                HStack(spacing: 8) {
                    // Shuffle button (hidden on shared tours)
                    if let shuffle = onShuffle {
                        Button(action: shuffle) {
                            Image(systemName: isShuffling ? "arrow.2.circlepath" : "arrow.2.circlepath")
                                .font(.system(size: 13))
                                .foregroundColor(Color("SlateMid"))
                                .rotationEffect(isShuffling ? .degrees(360) : .degrees(0))
                                .animation(isShuffling ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isShuffling)
                        }
                        .buttonStyle(.plain)
                        .disabled(isShuffling)
                    }

                    if isFirst {
                        Button(action: onStartHere) {
                            HStack(spacing: 3) {
                                Image(systemName: "mappin")
                                    .font(.system(size: 9))
                                Text("Start here")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(Color("Radish"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color("Radish").opacity(0.35), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    } else if let walk = stop.walk_time_from_previous, walk != "Starting point", !walk.isEmpty {
                        Text(walk)
                            .font(.system(size: 11))
                            .foregroundColor(Color("SlateMid"))
                            .fixedSize()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Row 2: cuisine · price · hours ──────────────────────────────
            HStack(spacing: 0) {
                Text(cuisineDisplay)
                    .foregroundColor(Color("SlateMid"))
                if !priceDisplay.isEmpty {
                    Text(" · ")
                        .foregroundColor(Color("SlateMid"))
                    Text(priceDisplay)
                        .foregroundColor(Color("TFTSlate").opacity(0.7))
                        .fontWeight(.medium)
                }
                Spacer()
                if let hours = todaysHours {
                    HStack(spacing: 3) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(hours)
                            .foregroundColor(hours == "Closed" ? Color.red : Color("SlateMid").opacity(0.8))
                            .fontWeight(hours == "Closed" ? .semibold : .regular)
                    }
                }
            }
            .font(.system(size: 12))
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // ── Photo strip — fixed HStack (no nested scroll to conflict
            //    with the parent vertical ScrollView's gesture recogniser) ──────
            if let photos = stop.photos, !photos.isEmpty {
                HStack(spacing: 8) {
                    ForEach(photos.prefix(4), id: \.self) { url in
                        AsyncImage(url: URL(string: url)) { phase in
                            switch phase {
                            case .success(let img): img.resizable().scaledToFill()
                            case .failure:          Color("CreamDark")
                            default:                Color("CreamDark").overlay(ProgressView().tint(Color("SlateMid")))
                            }
                        }
                        .frame(width: 100, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .clipped()
            }

            // ── Divider + description + link button ──────────────────────────
            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 10)

            // Description full-width, buttons below — matches web layout
            VStack(alignment: .leading, spacing: 10) {
                if let desc = stop.description, !desc.isEmpty {
                    Text(desc)
                        .font(.system(size: 12))
                        .foregroundColor(Color("SlateMid"))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                linkButton(for: stop)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stopLabel): \(stop.name). \(cuisineDisplay)\(priceDisplay.isEmpty ? "" : ", \(priceDisplay)").")
        .sheet(isPresented: $showMenu) {
            MenuViewerSheet(url: menuURLString, restaurantName: stop.name,
                           tourId: tourId, stopIndex: index)
        }
    }

    // Always returns a URL for the menu viewer — prefers menu_url, then
    // website_url, then falls back to a Google search so the button is
    // always visible and the viewer shows a graceful error/fallback.
    private var menuURLString: String {
        if let m = stop.menu_url, !m.isEmpty { return m }
        if let w = stop.website_url, !w.isEmpty, w != "https://example.com" { return w }
        let q = "\(stop.name) menu".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://www.google.com/search?q=\(q)"
    }

    // Always shows at least Directions. Shows menu/website when available.
    @ViewBuilder
    private func linkButton(for stop: TourStop) -> some View {
        let menuURL: URL? = {
            if let m = stop.menu_url, !m.isEmpty { return URL(string: m) }
            if let w = stop.website_url, !w.isEmpty, w != "https://example.com" { return URL(string: w) }
            return nil
        }()
        // Directions: prefer google_maps_url, fall back to search by name+address
        let mapsURL: URL = stop.google_maps_url.flatMap(URL.init)
            ?? URL(string: "https://maps.google.com/?q=\((stop.name + " " + (stop.address ?? "")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")")!

        HStack(spacing: 8) {
            // "View menu →" always visible — opens in-app MenuViewerSheet
            Button {
                showMenu = true
            } label: {
                outlineLinkLabel("View menu →")
            }
            .buttonStyle(.plain)
            // "Directions →" always opens Maps
            Link(destination: mapsURL) {
                outlineLinkLabel("Directions →")
            }
            .fixedSize()
        }
    }

    private func outlineLinkLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(Color("TFTSlate"))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.primary.opacity(0.2), lineWidth: 1)
            )
            .fixedSize()
    }
}

// MARK: - Small helpers
struct MetaChip: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundColor(Color("SlateMid"))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color("CreamDark").opacity(0.6))
            .clipShape(Capsule())
    }
}

extension View {
    func flexibleShrink() -> some View { self }
}

// TourMapView is now RouteSnapshotView (defined in MapViews.swift)

// MARK: - Preview
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
                         name: "Stateside", address: "300 E Pike St, Seattle, WA 98122",
                         lat: 47.6142, lng: -122.3264, cuisine_type: "Vietnamese",
                         cuisine_label: "Cult-Favorite Cocktail Bar",
                         price_level: 2, website_url: "https://statesidesea.com",
                         menu_url: nil, google_maps_url: nil,
                         description: "Their crispy spring rolls hit different at golden hour. Grab a window seat and let the fish sauce caramel do the talking.",
                         walk_time_from_previous: "Starting point",
                         rating: 4.5, photos: nil, opening_hours: ["Monday: 4:00 PM – 12:00 AM", "Tuesday: 4:00 PM – 12:00 AM"]),
                TourStop(stop_number: 2, stop_type: "main", place_id: "2",
                         name: "Altura", address: "617 Broadway E, Seattle, WA 98102",
                         lat: 47.6252, lng: -122.3209, cuisine_type: "Italian",
                         cuisine_label: "Intimate Italian Tasting Menu",
                         price_level: 4, website_url: "https://alturarestaurant.com",
                         menu_url: nil, google_maps_url: nil,
                         description: "Multi-course Italian that treats every plate like a love letter to the Pacific Northwest.",
                         walk_time_from_previous: "6 min walk",
                         rating: 4.8, photos: nil, opening_hours: nil),
                TourStop(stop_number: 3, stop_type: "dessert", place_id: "3",
                         name: "Molly Moon's", address: "917 E Pine St, Seattle, WA 98122",
                         lat: 47.6155, lng: -122.3198, cuisine_type: "Ice Cream",
                         cuisine_label: "Beloved Neighborhood Scoop Shop",
                         price_level: 1, website_url: "https://mollymoonicecream.com",
                         menu_url: nil, google_maps_url: nil,
                         description: "Salted caramel is the move, but the seasonal scoops are where the real magic lives.",
                         walk_time_from_previous: "4 min walk",
                         rating: 4.6, photos: nil, opening_hours: nil),
            ],
            created_at: Date().ISO8601Format(), user_id: nil, share_token: "preview",
            tourTitle: "Capitol Hill Golden Hour",
            totalDistanceMiles: 0.4
        )
    }
}
