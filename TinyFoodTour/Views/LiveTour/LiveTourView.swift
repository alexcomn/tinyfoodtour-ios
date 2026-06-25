import SwiftUI
import MapKit
import PhotosUI

struct LiveTourView: View {
    let tourId: String
    /// Called with completed stop indices + full progress array when "Look at my stops" is tapped.
    var onReviewStops: ((Set<Int>, [StopProgress]) -> Void)? = nil
    /// Called when the user wants to leave Live Tour without finishing
    /// (currently only the load-error "← Go back" state). Nil = fall back
    /// to environment dismiss (standalone/preview contexts).
    var onBack: (() -> Void)? = nil
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = LiveTourViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var showAuth = false

    var body: some View {
        ZStack {
            // ── Main content ───────────────────────────────────────────────
            if vm.isLoading {
                loadingView
            } else if let error = vm.errorMessage, vm.tour == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .scaledFont(size: 36)
                        .foregroundColor(Color("SlateMid"))
                    Text(error)
                        .scaledFont(size: 15)
                        .foregroundColor(Color("SlateMid"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("← Go back") { onBack?() ?? dismiss() }
                        .scaledFont(size: 14)
                        .foregroundColor(Color("Primary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Cream"))
            } else if let tour = vm.tour {
                mainContent(tour: tour)
            }

            // ── Full-screen completion overlay ────────────────────────────
            // Shown inline (no sheet) to avoid the iOS 26 presentation
            // coordinate transform that sheets and navigation destinations add.
            if vm.showCompletionCard, let tour = vm.tour {
                TourCompleteView(
                    tour: tour,
                    progress: vm.progress,
                    onBuildAnother: {
                        // No dismiss() here — same reasoning as onLookAtStops
                        // below. GeneratingView's own .buildAnotherTour
                        // listener pops itself off the stack.
                        vm.showCompletionCard = false
                        NotificationCenter.default.post(name: .buildAnotherTour, object: nil)
                    },
                    onLookAtStops: { indices, progress in
                        // No dismiss() here: LiveTourView is shown inline inside
                        // ResultsView (no separate navigation/sheet context), so
                        // @Environment(\.dismiss) actually pops the *parent*
                        // GeneratingView off the nav stack — landing the user back
                        // on the quiz. We just want ResultsView to swap back from
                        // LiveTourView to its results content.
                        vm.showCompletionCard = false
                        onReviewStops?(indices, progress)
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: vm.showCompletionCard)
        .navigationBarTitleDisplayMode(.inline)
        // LiveTourView is rendered *inline* inside ResultsView/GeneratingView
        // (no separate nav-stack entry of its own). A visible system back
        // button here actually controls GeneratingView's nav-stack entry —
        // tapping it pops GeneratingView and reveals QuizView exactly as the
        // user left it (its last step), which reads as "back button dumps me
        // at step 7 of the quiz". Hide it; use onBack/onReviewStops instead.
        .navigationBarBackButtonHidden(true)
        .darkStatusBar()
        .sheet(isPresented: $showAuth) {
            AuthView().environmentObject(authVM)
        }
        .task {
            await vm.load(tourId: tourId, userId: authVM.currentUser?.id)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView().tint(Color("Radish"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func mainContent(tour: Tour) -> some View {
        VStack(spacing: 0) {
            // Stop indicator dots
            stopDots(tour: tour)

            ScrollView {
                if let stop = vm.currentStop {
                    StopDetailView(
                        stop: stop,
                        allStops: tour.stops,
                        tourId: tourId,
                        mealType: tour.mealType,
                        vibes: tour.vibe,
                        index: vm.currentStopIndex,
                        total: tour.stops.count,
                        completedIndices: Set(vm.progress.indices.filter { vm.progress[$0].completed }),
                        progress: vm.currentProgress,
                        noteText: $vm.noteText,
                        isFavorite: vm.favorites.contains(stop.place_id),
                        isSaving: vm.isSaving,
                        isUploading: vm.isUploading,
                        isSignedIn: authVM.currentUser != nil,
                        onCheckOff: { Task { await vm.checkOff(userId: authVM.currentUser?.id) } },
                        onSaveNotes: { Task { await vm.saveNotes(userId: authVM.currentUser?.id) } },
                        onToggleFavorite: { Task { await vm.toggleFavorite(stop: stop, userId: authVM.currentUser?.id) } },
                        onUploadPhoto: { data in Task { await vm.uploadPhoto(data: data, userId: authVM.currentUser?.id) } },
                        onSignIn: { showAuth = true }
                    )
                }
            }

            // Prev / Next nav
            stopNavBar(tour: tour)
        }
        .background(Color("Cream"))
        .ignoresSafeArea(edges: .bottom)
    }

    private func stopDots(tour: Tour) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<tour.stops.count, id: \.self) { i in
                Button {
                    Task { await vm.saveNotes(userId: authVM.currentUser?.id) }
                    vm.currentStopIndex = i
                    vm.noteText = vm.progress[safe: i]?.notes ?? ""
                } label: {
                    Circle()
                        .fill(vm.progress[safe: i]?.completed == true
                              ? StopLabel.color(index: i)
                              : (i == vm.currentStopIndex ? StopLabel.color(index: i).opacity(0.5) : Color.primary.opacity(0.15)))
                        .frame(width: i == vm.currentStopIndex ? 10 : 8, height: i == vm.currentStopIndex ? 10 : 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 14)
    }

    private func stopNavBar(tour: Tour) -> some View {
        HStack {
            Button {
                guard vm.currentStopIndex > 0 else { return }
                // Auto-save any unsaved notes before leaving this stop
                Task { await vm.saveNotes(userId: authVM.currentUser?.id) }
                vm.currentStopIndex -= 1
                vm.noteText = vm.progress[safe: vm.currentStopIndex]?.notes ?? ""
            } label: {
                Image(systemName: "chevron.left")
                    .scaledFont(size: 16, weight: .medium)
                    .foregroundColor(vm.currentStopIndex > 0 ? .primary : .primary.opacity(0.2))
            }
            .disabled(vm.currentStopIndex == 0)

            Spacer()

            Text("\(vm.currentStopIndex + 1) of \(tour.stops.count)")
                .scaledFont(size: 13)
                .foregroundColor(.secondary)

            Spacer()

            if vm.currentStopIndex < tour.stops.count - 1 {
                Button {
                    Task { await vm.saveNotes(userId: authVM.currentUser?.id) }
                    vm.currentStopIndex += 1
                    vm.noteText = vm.progress[safe: vm.currentStopIndex]?.notes ?? ""
                } label: {
                    Image(systemName: "chevron.right")
                        .scaledFont(size: 16, weight: .medium)
                        .foregroundColor(.primary)
                }
            } else {
                Button {
                    vm.showCompletionCard = true
                } label: {
                    Text("Finish 🎉")
                        .scaledFont(size: 14, weight: .semibold)
                        .foregroundColor(Color("Radish"))
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.bottom, max(20, UIApplication.safeAreaBottom))
    }
}

// MARK: - Individual stop detail
struct StopDetailView: View {
    let stop: TourStop
    let allStops: [TourStop]
    let tourId: String
    let mealType: String?
    let vibes: [String]
    let index: Int
    let total: Int
    let completedIndices: Set<Int>
    let progress: StopProgress
    @Binding var noteText: String
    let isFavorite: Bool
    let isSaving: Bool
    let isUploading: Bool
    let isSignedIn: Bool          // gate photo uploads behind auth
    let onCheckOff: () -> Void
    let onSaveNotes: () -> Void
    let onToggleFavorite: () -> Void
    let onUploadPhoto: (Data) -> Void
    var onSignIn: (() -> Void)? = nil

    @State private var photoItem: PhotosPickerItem?
    @State private var showMenu = false
    @State private var showDirections = false
    @State private var noteSaved = false       // brief "Saved!" confirmation
    @FocusState private var notesFocused: Bool // keyboard dismiss

    private var menuURLString: String {
        if let m = stop.menu_url, !m.isEmpty { return m }
        if let w = stop.website_url, !w.isEmpty, w != "https://example.com" { return w }
        let q = "\(stop.name) menu".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://www.google.com/search?q=\(q)"
    }

    var stopColor: Color { StopLabel.color(index: index) }
    var label: String { StopLabel.label(index: index, total: total, mealType: mealType, vibes: vibes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Stop header
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .scaledFont(size: 11, weight: .bold)
                    .foregroundColor(stopColor)
                    .kerning(1.2)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(TFTFont.heading(22))
                        Text([stop.cuisine_type, stop.price_level.map { String(repeating: "$", count: max(1, $0)) }]
                        .compactMap { $0 }.joined(separator: " · "))
                            .scaledFont(size: 14)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .scaledFont(size: 20)
                            .foregroundColor(isFavorite ? Color("Radish") : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Route map — shows all stops, highlights current. Uses
            // MiniMapView's default height (matches RouteSnapshotView's
            // default used by ResultsView.mapSection) so the map is the same
            // size and the route sits in the same place on both screens.
            MiniMapView(stop: stop, allStops: allStops, currentIndex: index,
                       completedIndices: completedIndices)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 20)

            // Walk time + address
            VStack(alignment: .leading, spacing: 4) {
                if let walkTime = stop.walk_time_from_previous, walkTime != "Starting point" {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .scaledFont(size: 12)
                        Text(walkTime)
                            .scaledFont(size: 13)
                    }
                    .foregroundColor(.secondary)
                }
                if let addr = stop.address {
                    Text(addr)
                        .scaledFont(size: 13)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Description
            if let desc = stop.description {
                Text(desc)
                    .scaledFont(size: 15)
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }

            // Action links
            HStack(spacing: 16) {
                if let url = directionsURL(for: stop) {
                    Link(destination: url) {
                        Label("Directions", systemImage: "map.fill")
                            .scaledFont(size: 13, weight: .medium)
                            .foregroundColor(Color("Radish"))
                    }
                }
                Button {
                    showMenu = true
                } label: {
                    Label("Menu", systemImage: "menucard")
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(Color("Radish"))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showMenu) {
                    MenuViewerSheet(url: menuURLString, restaurantName: stop.name,
                                   tourId: tourId, stopIndex: index)
                }
            }
            .padding(.horizontal, 20)

            Divider().padding(.horizontal, 20)

            // Check-off button
            Button(action: onCheckOff) {
                HStack(spacing: 8) {
                    Image(systemName: progress.completed ? "checkmark.circle.fill" : "circle")
                        .scaledFont(size: 20)
                        .foregroundColor(progress.completed ? .green : .secondary)
                    Text(progress.completed ? "Stop checked off! 🎉" : "Mark this stop as visited")
                        .scaledFont(size: 15, weight: .medium)
                        .foregroundColor(progress.completed ? .green : .primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(progress.completed ? "Visited — tap to unmark" : "Mark \(stop.name) as visited")
            .padding(.horizontal, 20)

            // ── Notes ────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .scaledFont(size: 13, weight: .semibold)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                TextEditor(text: $noteText)
                    .scaledFont(size: 14)
                    .frame(minHeight: 80)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)
                    .focused($notesFocused)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") { notesFocused = false }
                                .foregroundColor(Color("Primary"))
                        }
                    }

                HStack(spacing: 16) {
                    Button {
                        notesFocused = false
                        onSaveNotes()
                        // Show brief "Saved!" confirmation
                        noteSaved = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { noteSaved = false }
                    } label: {
                        HStack(spacing: 4) {
                            if noteSaved {
                                Image(systemName: "checkmark.circle.fill")
                                    .scaledFont(size: 12)
                                Text("Saved!")
                            } else {
                                Text(isSaving ? "Saving…" : "Save notes")
                            }
                        }
                        .scaledFont(size: 13, weight: .medium)
                        .foregroundColor(noteSaved ? .green : Color("Radish"))
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 20)
            }

            // ── Photos ────────────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Photos")
                        .scaledFont(size: 13, weight: .semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                    if isSignedIn {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Add photo", systemImage: "camera")
                                .scaledFont(size: 13)
                                .foregroundColor(Color("Radish"))
                        }
                        .onChange(of: photoItem) { _, item in
                            guard let item else { return }
                            Task {
                                // Normalize to JPEG via UIImage so MIME type is always correct
                                if let data = try? await item.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data),
                                   let jpeg = uiImage.jpegData(compressionQuality: 0.8) {
                                    onUploadPhoto(jpeg)
                                }
                                // Reset so selecting the same photo again re-triggers onChange
                                photoItem = nil
                            }
                        }
                    } else {
                        Button {
                            onSignIn?()
                        } label: {
                            Label("Sign in to add photos", systemImage: "person.circle")
                                .scaledFont(size: 12)
                                .foregroundColor(Color("Radish"))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)

                if isUploading {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("Uploading photo…")
                            .scaledFont(size: 12)
                            .foregroundColor(Color("SlateMid"))
                    }
                    .padding(.horizontal, 20)
                }

                if !progress.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(progress.photos, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Color(.secondarySystemBackground)
                                        .overlay(ProgressView().scaleEffect(0.7))
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }

            Spacer(minLength: 40)
        }
    }

    // Prefer coordinate-based Apple Maps — always works on iOS, no "No results
    // found" since we pass exact lat/lng. Falls back to the DB's google_maps_url
    // then an address search if coordinates aren't available.
    private func directionsURL(for stop: TourStop) -> URL? {
        if let lat = stop.lat, let lng = stop.lng {
            let name = stop.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            return URL(string: "maps://?ll=\(lat),\(lng)&q=\(name)")
        }
        if let gmUrl = stop.google_maps_url { return URL(string: gmUrl) }
        let q = (stop.name + " " + (stop.address ?? ""))
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return URL(string: "https://maps.apple.com/?q=\(q)")
    }
}

// MiniMapView is defined in MapViews.swift

// MARK: - Completion card
struct CompletionCardView: View {
    let tour: Tour
    var onBuildAnother: (() -> Void)? = nil
    var onReviewStops: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            BrandMarkView(fontSize: 20)
                .padding(.top, 32)
            Text("You conquered today's\nTiNY FOOD TOUR!")
                .font(TFTFont.heading(26))
                .multilineTextAlignment(.center)
            Text("Every stop in \(tour.neighborhood), on foot.")
                .scaledFont(size: 15)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            // Primary: build another tour
            Button {
                dismiss()
                onBuildAnother?()
            } label: {
                Text("Build another tour →")
                    .scaledFont(size: 15, weight: .semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("Primary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 4)
            // Secondary: go back to Results to review all stop cards
            Button("Review your stops") {
                dismiss()
                onReviewStops?()
            }
                .scaledFont(size: 14)
                .foregroundColor(Color("SlateMid"))
            Spacer()
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        LiveTourView(tourId: "preview-id")
            .environmentObject(AuthViewModel())
    }
}
