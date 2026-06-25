import SwiftUI
import MapKit

// MARK: - Results screen
// Design mirrors Results.tsx: pizza-crust header, white stop cards, circular color
// badge, serif headings, photo strips, today's hours, link buttons.

struct ResultsView: View {
    let tour: Tour
    let isShared: Bool
    let generationParams: QuizAnswers?
    /// Called when the back button is tapped in inline (non-sheet) presentation.
    /// Nil = use environment dismiss (sheet/modal contexts).
    var onBack: (() -> Void)? = nil

    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var savedVM = SavedToursViewModel()
    @StateObject private var tweakVM = TourViewModel()
    @StateObject private var reactionsVM: ReactionsViewModel
    @State private var showLiveTour = false
    @State private var completedStopIndices: Set<Int> = []   // populated when user reviews after completing
    @State private var tourProgress: [StopProgress]? = nil  // user photos/notes per stop, set after completing
    @State private var isSaved = false
    @State private var currentTour: Tour
    @State private var shufflingIndex: Int? = nil
    @State private var smartShufflingIndex: Int? = nil
    @State private var smartShuffleErrorIndex: Int? = nil
    @State private var smartShuffleError: String? = nil
    @State private var showTweaks = false
    @State private var tweakStops: Double
    @State private var tweakPrice: Double
    @State private var isRenderingShareImage = false
    @State private var shareCardImage: UIImage? = nil
    @State private var isShareCardPresented = false

    init(tour: Tour, isShared: Bool, generationParams: QuizAnswers?, onBack: (() -> Void)? = nil) {
        self.tour = tour
        self.isShared = isShared
        self.generationParams = generationParams
        self.onBack = onBack
        _currentTour = State(initialValue: tour)
        _reactionsVM = StateObject(wrappedValue: ReactionsViewModel(shareToken: tour.share_token))
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
        // LiveTourView shown inline — same reason as GeneratingView→ResultsView:
        // any iOS 26 presentation adds a coordinate transform. Inline swap has none.
        if showLiveTour {
            LiveTourView(
                tourId: currentTour.id,
                onReviewStops: { indices, progress in
                    completedStopIndices = indices
                    tourProgress = progress
                    showLiveTour = false
                },
                onBack: {
                    // Leave Live Tour without finishing — swap back to the
                    // results content. Must NOT use dismiss(): LiveTourView
                    // is inline here, so dismiss() resolves to the parent
                    // GeneratingView's dismiss and pops the whole flow.
                    showLiveTour = false
                }
            )
            .environmentObject(authVM)
        } else {
            resultsContent
        }
    }

    private var resultsContent: some View {
        // GeometryReader gives the ScrollView an EXPLICIT bounded height (geo.size.height).
        // Without an explicit bound, a ScrollView in a conditionally-rendered view nested
        // several navigationDestinations deep can size itself to its content height and
        // therefore never scroll. Framing it to the geometry size guarantees scrolling
        // whenever content overflows. navRow floats via .overlay (no layout/scroll impact).
        GeometryReader { geo in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 56)   // reserve room for the floating navRow
                    header
                    mapSection

                    if stops.isEmpty {
                        emptyStopsView
                    } else {
                        VStack(spacing: 12) {
                            ForEach(Array(stops.enumerated()), id: \.element.place_id) { idx, stop in
                                // Disable shuffle controls on shared tours and in review mode
                                let inReviewMode = tourProgress != nil
                                let shuffleAction: (() -> Void)? = (isShared || inReviewMode) ? nil : {
                                    Task { await shuffleStop(at: idx) }
                                }
                                let smartShuffleAction: ((String) -> Void)? = (isShared || inReviewMode) ? nil : { instructions in
                                    Task { await smartShuffleStop(at: idx, instructions: instructions) }
                                }
                                StopCard(
                                    stop: stop,
                                    tourId: currentTour.id,
                                    index: idx,
                                    total: stops.count,
                                    mealType: currentTour.mealType,
                                    vibes: currentTour.vibe,
                                    isFirst: idx == 0,
                                    isCompleted: completedStopIndices.contains(idx),
                                    progress: tourProgress?[safe: idx],
                                    isShuffling: shufflingIndex == idx,
                                    isSmartShuffling: smartShufflingIndex == idx,
                                    smartShuffleError: smartShuffleErrorIndex == idx ? smartShuffleError : nil,
                                    reactionsVM: reactionsVM,
                                    onStartHere: { showLiveTour = true },
                                    onShuffle: shuffleAction,
                                    onSmartShuffle: smartShuffleAction
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }

                    actionBar
                }
                .frame(width: geo.size.width)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .background(Color("Cream"))
            .overlay(alignment: .top) { navRow }
        }
        .task { await reactionsVM.load() }
        .ignoresSafeArea(edges: .bottom)
        .navigationBarBackButtonHidden(true)
        .darkStatusBar()
        .sheet(isPresented: $showTweaks) { tweaksSheet }
        .onChange(of: tweakVM.tour) { _, newTour in
            if let t = newTour { currentTour = t; showTweaks = false }
        }
    }

    private var navRow: some View {
        HStack {
            Button {
                if let back = onBack { back() } else { dismiss() }
            } label: {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 17, weight: .semibold)
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
                        .scaledFont(size: 15)
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

    // MARK: - Header (bg-pizza-crust)
    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandMarkView(fontSize: 15)
                .padding(.bottom, 12)

            Text(tour.displayTitle)
                .font(TFTFont.heading(30))
                .foregroundColor(Color("Primary"))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 6)

            // Plain dot-separated line — matches web "3 stops · ~0.4 mi · ~10 min walking"
            Text(tourMetaLine)
                .scaledFont(size: 13)
                .foregroundColor(Color("SlateMid"))

            // Tour-level reactions
            ReactionBar(vm: reactionsVM, stopIndex: nil)
                .padding(.horizontal, -20)  // cancel parent padding so pills flush-left
                .padding(.top, 10)

            // Completion summary — only shown when returning from Live Tour
            if !completedStopIndices.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: completedStopIndices.count == stops.count
                          ? "checkmark.circle.fill" : "checkmark.circle")
                        .scaledFont(size: 13)
                        .foregroundColor(.green)
                    Text(completedStopIndices.count == stops.count
                         ? "All \(stops.count) stops visited"
                         : "\(completedStopIndices.count) of \(stops.count) stops visited")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            }
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
                        .scaledFont(size: 12)
                        .foregroundColor(Color("TFTOrange"))
                    Text("We stretched a bit — one of these is from a previous tour. Slim pickings in this corner of the map.")
                        .scaledFont(size: 12)
                        .foregroundColor(Color("SlateMid"))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Pass completedIndices so the post-tour review map matches the
            // Live Tour map exactly (same green ✓ markers, same framing/size).
            RouteSnapshotView(stops: stops, completedIndices: completedStopIndices)
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

    // MARK: - Smart shuffle (natural-language replacement request)
    // Mirrors handleSmartShuffle in web's Results.tsx — calls the smart-shuffle
    // edge function with { tour_id, stop_index, instructions } and expects
    // either { stop: <TourStop> } or { error: string } back. Unlike the web app,
    // the iOS tour is always persisted at generation time (generate-tour inserts
    // the row server-side and returns a real id), so there's no "save first" step.
    private func smartShuffleStop(at index: Int, instructions: String) async {
        guard smartShufflingIndex == nil else { return }
        smartShufflingIndex = index
        smartShuffleErrorIndex = nil
        smartShuffleError = nil
        struct SmartShuffleResponse: Codable { let stop: TourStop?; let error: String? }
        do {
            let result: SmartShuffleResponse = try await SupabaseService.shared.invokeFunction(
                name: "smart-shuffle",
                body: ["tour_id": currentTour.id, "stop_index": index, "instructions": instructions]
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
            } else if let message = result.error {
                smartShuffleErrorIndex = index
                smartShuffleError = message
            }
        } catch {
            smartShuffleErrorIndex = index
            smartShuffleError = "Couldn't find a match — try a different request."
        }
        smartShufflingIndex = nil
    }

    // MARK: - Tweaks sheet
    private var tweaksSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 28) {
                // Stops slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Stops")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(Color("Foreground"))
                        Spacer()
                        Text("\(Int(tweakStops))")
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundColor(Color("Primary"))
                    }
                    Slider(value: $tweakStops, in: 2...5, step: 1)
                        .tint(Color("Primary"))
                    HStack {
                        Text("2").scaledFont(size: 11).foregroundColor(Color("SlateMid"))
                        Spacer()
                        Text("5").scaledFont(size: 11).foregroundColor(Color("SlateMid"))
                    }
                }

                // Pricing slider
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Pricing")
                            .scaledFont(size: 14, weight: .medium)
                            .foregroundColor(Color("Foreground"))
                        Spacer()
                        Text(String(repeating: "$", count: Int(tweakPrice)))
                            .scaledFont(size: 14, weight: .semibold)
                            .foregroundColor(Color("Primary"))
                    }
                    Slider(value: $tweakPrice, in: 1...4, step: 1)
                        .tint(Color("Primary"))
                    HStack {
                        Text("$").scaledFont(size: 11).foregroundColor(Color("SlateMid"))
                        Spacer()
                        Text("$$$$").scaledFont(size: 11).foregroundColor(Color("SlateMid"))
                    }
                }

                Spacer()

                // Apply
                if tweakVM.isGenerating {
                    HStack(spacing: 10) {
                        ProgressView().tint(Color("Radish"))
                        Text(tweakVM.generatingMessage)
                            .scaledFont(size: 13)
                            .foregroundColor(Color("Radish"))
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    CTAButton(title: "Apply filters", isEnabled: true) {
                        guard var params = generationParams else { return }
                        params.walkDistance = params.walkDistance.isEmpty
                            ? "A short stroll (10 min)" : params.walkDistance
                        Task {
                            let tweakedParams = params
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
                .scaledFont(size: 40)
                .foregroundColor(Color("SlateMid"))
            Text("We couldn't find stops for this tour.")
                .scaledFont(size: 15, weight: .medium)
                .foregroundColor(Color("TFTSlate"))
            Text("Try a different neighborhood or adjust your preferences.")
                .scaledFont(size: 13)
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
                // "Start my tour" hidden once the user has completed the tour
                if tourProgress == nil {
                    Button {
                        showLiveTour = true
                    } label: {
                        Text("Start my tour →")
                        .scaledFont(size: 15, weight: .semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }

                // Save + Share (image) + Share (link)
                HStack(spacing: 16) {
                    Button {
                        Task {
                            await savedVM.saveTour(tour: currentTour, userId: authVM.currentUser?.id)
                            isSaved = true
                        }
                    } label: {
                        Label(isSaved ? "Saved!" : "Save",
                              systemImage: isSaved ? "bookmark.fill" : "bookmark")
                            .scaledFont(size: 14)
                            .foregroundColor(isSaved ? Color("Radish") : Color("SlateMid"))
                    }

                    Spacer()

                    // Share card image
                    Button {
                        Task { await generateShareCardImage() }
                    } label: {
                        if isRenderingShareImage {
                            ProgressView().tint(Color("SlateMid")).scaleEffect(0.75)
                        } else {
                            Image(systemName: "camera")
                                .scaledFont(size: 15)
                                .foregroundColor(Color("SlateMid"))
                        }
                    }
                    .disabled(isRenderingShareImage)

                    // Share link
                    if let shareURL = URL(string: "https://tinyfoodtour.com/tour/\(currentTour.share_token)") {
                        ShareLink(
                            item: shareURL,
                            subject: Text(currentTour.displayTitle),
                            message: Text("Check out this food tour I built on Tiny Food Tour!")
                        ) {
                            Image(systemName: "link")
                                .scaledFont(size: 15)
                                .foregroundColor(Color("SlateMid"))
                        }
                    }
                }

                // "Go to my profile" — shown after completing the tour
                if tourProgress != nil {
                    Button {
                        NotificationCenter.default.post(name: .goToProfile, object: nil)
                    } label: {
                        Text("Go to my profile →")
                            .scaledFont(size: 13)
                            .foregroundColor(Color("SlateMid"))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .sheet(isPresented: $isShareCardPresented) {
            if let img = shareCardImage {
                ShareSheet(items: [img])
                    .presentationDetents([.medium, .large])
            }
        }
    }

    @MainActor
    private func generateShareCardImage() async {
        isRenderingShareImage = true
        let mapImg = await renderTourRouteMapImage(stops: currentTour.stops)
        let cardView = TourShareCardView(tour: currentTour, progress: tourProgress ?? [], mapImage: mapImg)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        shareCardImage = renderer.uiImage
        isRenderingShareImage = false
        isShareCardPresented = true
    }
}

// MARK: - Stop card
struct StopCard: View {
    @State private var showMenu = false
    @State private var showSmartShuffle = false
    @State private var smartShuffleText = ""
    @State private var isNameExpanded = false
    let stop: TourStop
    let tourId: String           // for menu_items DB lookup
    let index: Int
    let total: Int
    let mealType: String?
    let vibes: [String]
    let isFirst: Bool
    let isCompleted: Bool        // true when returning from Live Tour with this stop visited
    var progress: StopProgress? = nil  // user photos + notes from Live Tour; nil before tour is taken
    let isShuffling: Bool
    let isSmartShuffling: Bool
    let smartShuffleError: String?
    let reactionsVM: ReactionsViewModel
    let onStartHere: () -> Void
    let onShuffle: (() -> Void)?
    let onSmartShuffle: ((String) -> Void)?

    private var stopColor: Color { StopLabel.color(index: index) }
    private var stopLabel: String { StopLabel.label(index: index, total: total, mealType: mealType, vibes: vibes) }

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

    // Today's hours — shows "Closed · Reopens [day] HH:MM AM/PM" per tone brief §3
    private var todaysHours: String? {
        guard let hours = stop.opening_hours, !hours.isEmpty else { return nil }
        let days = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        let weekday = Calendar.current.component(.weekday, from: Date()) - 1  // 0=Sun
        let today = days[weekday]
        guard let line = hours.first(where: { $0.hasPrefix(today) }) else { return nil }
        let hoursStr = line.replacingOccurrences(of: "\(today): ", with: "")
        guard hoursStr == "Closed" else { return hoursStr }
        // Find the next day the stop is open and show its opening time
        for offset in 1...7 {
            let nextDay = days[(weekday + offset) % 7]
            if let nextLine = hours.first(where: { $0.hasPrefix(nextDay) }) {
                let nextHours = nextLine.replacingOccurrences(of: "\(nextDay): ", with: "")
                if nextHours != "Closed", let openTime = nextHours.components(separatedBy: " – ").first {
                    let label = offset == 1 ? "tomorrow" : nextDay
                    return "Closed · Reopens \(label) \(openTime)"
                }
            }
        }
        return "Closed"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Row 1: badge · label · walk time · actions ──────────────────
            HStack(alignment: .center, spacing: 8) {
                // Badge: green ✓ if visited, brand colour + number otherwise
                ZStack {
                    Circle().fill(isCompleted ? Color(hex: "#22c55e") : stopColor)
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .scaledFont(size: 12, weight: .bold)
                            .foregroundColor(.white)
                    } else {
                        Text(String(format: "%02d", index + 1))
                            .scaledFont(size: 11, weight: .semibold)
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 30, height: 30)

                Text(stopLabel)
                    .scaledFont(size: 10, weight: .medium)
                    .kerning(1.5)
                    .foregroundColor(stopColor)

                Spacer()

                // Walk time for non-first stops
                if !isFirst, let walk = stop.walk_time_from_previous, walk != "Starting point", !walk.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .scaledFont(size: 10)
                        Text(walk)
                            .scaledFont(size: 11)
                    }
                    .foregroundColor(Color("SlateMid"))
                }

                // Shuffle button (hidden on shared tours)
                if let shuffle = onShuffle {
                    Button(action: shuffle) {
                        Image(systemName: "arrow.2.circlepath")
                            .scaledFont(size: 13)
                            .foregroundColor(Color("SlateMid"))
                            .rotationEffect(isShuffling ? .degrees(360) : .degrees(0))
                            .animation(isShuffling ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: isShuffling)
                    }
                    .buttonStyle(.plain)
                    .disabled(isShuffling)
                }

                // Smart shuffle — natural-language replacement request (hidden on shared tours)
                if let smartShuffle = onSmartShuffle {
                    Button {
                        showSmartShuffle = true
                    } label: {
                        Image(systemName: isSmartShuffling ? "ellipsis.message.fill" : "message")
                            .scaledFont(size: 13)
                            .foregroundColor(Color("SlateMid"))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSmartShuffling)
                    .accessibilityLabel("Request a specific replacement")
                    .popover(isPresented: $showSmartShuffle) {
                        smartShufflePopover(onSubmit: smartShuffle)
                    }
                }

                if isFirst {
                    Button(action: onStartHere) {
                        HStack(spacing: 3) {
                            Image(systemName: "mappin")
                                .scaledFont(size: 9)
                            Text("Start here")
                                .scaledFont(size: 10, weight: .medium)
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
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Row 2: restaurant name (full-width, 2-line clamp, tap to expand) ──
            Text(stop.name)
                .font(TFTFont.heading(17))
                .foregroundColor(Color("TFTSlate"))
                .lineLimit(isNameExpanded ? nil : 2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onTapGesture { isNameExpanded.toggle() }
                .padding(.horizontal, 16)
                .padding(.top, 6)

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
                            .scaledFont(size: 9)
                        Text(hours)
                            .foregroundColor(hours.hasPrefix("Closed") ? Color.red : Color("SlateMid").opacity(0.8))
                            .fontWeight(hours.hasPrefix("Closed") ? .semibold : .regular)
                    }
                }
            }
            .scaledFont(size: 12)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // ── Photo strip — horizontal ScrollView ──────────────────────────
            // MUST be a ScrollView, not a fixed HStack: 4×100pt images = 424pt is
            // wider than the screen. A fixed HStack reports that 424pt as its layout
            // width (.clipped only clips rendering), forcing the entire card column
            // wider than the viewport → left-edge clipping + broken vertical scroll.
            // A horizontal ScrollView bounds its layout width to what's available
            // and scrolls internally for the overflow.
            if let photos = stop.photos, !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
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
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 10)
            }

            // ── User photos from Live Tour ────────────────────────────────
            if let userPhotos = progress?.photos, !userPhotos.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("YOUR PHOTOS")
                        .scaledFont(size: 9, weight: .semibold)
                        .foregroundColor(Color("SlateMid"))
                        .tracking(1.5)
                        .padding(.horizontal, 16)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(userPhotos, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { phase in
                                    switch phase {
                                    case .success(let img): img.resizable().scaledToFill()
                                    case .failure:          Color("CreamDark")
                                    default:                Color("CreamDark").overlay(ProgressView().tint(Color("SlateMid")))
                                    }
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08), lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 8)
            }

            // ── Divider + description + link button ──────────────────────────
            Divider()
                .padding(.horizontal, 16)
                .padding(.top, 10)

            // Description full-width, buttons below — matches web layout
            VStack(alignment: .leading, spacing: 10) {
                if let desc = stop.description, !desc.isEmpty {
                    Text(desc)
                        .scaledFont(size: 12)
                        .foregroundColor(Color("SlateMid"))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                // ── User notes from Live Tour ─────────────────────────────
                if let notes = progress?.notes,
                   !notes.trimmingCharacters(in: .whitespaces).isEmpty {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "note.text")
                            .scaledFont(size: 12)
                            .foregroundColor(Color("SlateMid"))
                            .padding(.top, 1)
                        Text(notes)
                            .scaledFont(size: 12)
                            .foregroundColor(Color("TFTSlate"))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("CreamDark"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                linkButton(for: stop)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)

            // Stop-level reactions
            ReactionBar(vm: reactionsVM, stopIndex: index)
                .padding(.bottom, 12)
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
            MenuViewerSheet(
                url: menuURL,
                restaurantName: stop.name,
                address: stop.address,
                websiteURL: stop.website_url,
                tourId: tourId,
                stopIndex: index
            )
        }
    }

    // Chat-bubble popover for natural-language replacement requests — mirrors
    // web's Results.tsx (~lines 840-900): a short text field + "Go" button that
    // calls smart-shuffle with free-form instructions ("something cheaper",
    // "has outdoor seating"). Closes itself on submit; ResultsView owns the
    // network call and loading/error state (passed back down as props).
    @ViewBuilder
    private func smartShufflePopover(onSubmit: @escaping (String) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Request a specific replacement")
                .scaledFont(size: 13, weight: .semibold)
                .foregroundColor(Color("TFTSlate"))
            Text("e.g. \u{201C}something cheaper\u{201D} or \u{201C}has outdoor seating\u{201D}")
                .scaledFont(size: 11)
                .foregroundColor(Color("SlateMid"))

            HStack(spacing: 8) {
                TextField("Type your request…", text: $smartShuffleText)
                    .scaledFont(size: 13)
                    .textFieldStyle(.roundedBorder)
                    .disabled(isSmartShuffling)
                    .submitLabel(.go)
                    .onSubmit(submitSmartShuffle(onSubmit))

                Button("Go") { submitSmartShuffle(onSubmit)() }
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(Color("Primary"))
                    .disabled(isSmartShuffling || smartShuffleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if isSmartShuffling {
                HStack(spacing: 6) {
                    ProgressView().tint(Color("SlateMid")).scaleEffect(0.7)
                    Text("Looking for a match…")
                        .scaledFont(size: 11)
                        .foregroundColor(Color("SlateMid"))
                }
            } else if let error = smartShuffleError {
                Text(error)
                    .scaledFont(size: 11)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(width: 280)
        .presentationCompactAdaptation(.popover)
    }

    private func submitSmartShuffle(_ onSubmit: @escaping (String) -> Void) -> () -> Void {
        {
            let trimmed = smartShuffleText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !isSmartShuffling else { return }
            onSubmit(trimmed)
            showSmartShuffle = false
            smartShuffleText = ""
        }
    }

    // Returns the best available URL for menu scraping: prefers menu_url,
    // then website_url. Returns nil when neither is available so MenuViewerSheet
    // can skip the fetch-menu call and go straight to a rich fallback state.
    private var menuURL: String? {
        if let m = stop.menu_url, !m.isEmpty { return m }
        if let w = stop.website_url, !w.isEmpty, w != "https://example.com" { return w }
        return nil
    }

    // Always shows at least Directions. Shows menu/website when available.
    @ViewBuilder
    private func linkButton(for stop: TourStop) -> some View {
        let menuURL: URL? = self.menuURL.flatMap(URL.init)
        // Prefer coordinate-based Apple Maps: always works on iOS, no "No results found"
        let mapsURL: URL = {
            if let lat = stop.lat, let lng = stop.lng {
                let name = stop.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return URL(string: "maps://?ll=\(lat),\(lng)&q=\(name)") ?? URL(string: "https://maps.apple.com/")!
            }
            if let gm = stop.google_maps_url.flatMap(URL.init) { return gm }
            let q = (stop.name + " " + (stop.address ?? "")).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "https://maps.apple.com/?q=\(q)") ?? URL(string: "https://maps.apple.com/")!
        }()

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
            .scaledFont(size: 11)
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
            .scaledFont(size: 11)
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

