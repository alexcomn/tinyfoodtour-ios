import SwiftUI
import MapKit
import PhotosUI

struct LiveTourView: View {
    let tourId: String
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = LiveTourViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            if vm.isLoading {
                loadingView
            } else if let error = vm.errorMessage, vm.tour == nil {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.circle")
                        .font(.system(size: 36))
                        .foregroundColor(Color("SlateMid"))
                    Text(error)
                        .font(.system(size: 15))
                        .foregroundColor(Color("SlateMid"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("← Go back") { dismiss() }
                        .font(.system(size: 14))
                        .foregroundColor(Color("Primary"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color("Cream"))
            } else if let tour = vm.tour {
                mainContent(tour: tour)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .darkStatusBar()
        .sheet(isPresented: $vm.showCompletionCard) {
            if let tour = vm.tour {
                CompletionCardView(tour: tour) {
                    // Pop back through the nav stack to Home, then launch quiz
                    NotificationCenter.default.post(name: .buildAnotherTour, object: nil)
                }
            }
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
                        index: vm.currentStopIndex,
                        total: tour.stops.count,
                        progress: vm.currentProgress,
                        noteText: $vm.noteText,
                        isFavorite: vm.favorites.contains(stop.place_id),
                        isSaving: vm.isSaving,
                        isUploading: vm.isUploading,
                        onCheckOff: { Task { await vm.checkOff(userId: authVM.currentUser?.id) } },
                        onSaveNotes: { Task { await vm.saveNotes(userId: authVM.currentUser?.id) } },
                        onToggleFavorite: { Task { await vm.toggleFavorite(stop: stop, userId: authVM.currentUser?.id) } },
                        onUploadPhoto: { data in Task { await vm.uploadPhoto(data: data, userId: authVM.currentUser?.id) } }
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
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(vm.currentStopIndex > 0 ? .primary : .primary.opacity(0.2))
            }
            .disabled(vm.currentStopIndex == 0)

            Spacer()

            Text("\(vm.currentStopIndex + 1) of \(tour.stops.count)")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Spacer()

            if vm.currentStopIndex < tour.stops.count - 1 {
                Button {
                    Task { await vm.saveNotes(userId: authVM.currentUser?.id) }
                    vm.currentStopIndex += 1
                    vm.noteText = vm.progress[safe: vm.currentStopIndex]?.notes ?? ""
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                }
            } else {
                Button {
                    vm.showCompletionCard = true
                } label: {
                    Text("Finish 🎉")
                        .font(.system(size: 14, weight: .semibold))
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
    let index: Int
    let total: Int
    let progress: StopProgress
    @Binding var noteText: String
    let isFavorite: Bool
    let isSaving: Bool
    let isUploading: Bool
    let onCheckOff: () -> Void
    let onSaveNotes: () -> Void
    let onToggleFavorite: () -> Void
    let onUploadPhoto: (Data) -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var showDirections = false

    var stopColor: Color { StopLabel.color(index: index) }
    var label: String { StopLabel.label(index: index, total: total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Stop header
            VStack(alignment: .leading, spacing: 6) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(stopColor)
                    .kerning(1.2)

                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.name)
                            .font(.system(size: 22, weight: .bold, design: .serif))
                        Text([stop.cuisine_type, stop.price_level.map { String(repeating: "$", count: max(1, $0)) }]
                        .compactMap { $0 }.joined(separator: " · "))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button(action: onToggleFavorite) {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(isFavorite ? Color("Radish") : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            // Route map — shows all stops, highlights current
            MiniMapView(stop: stop, allStops: allStops, currentIndex: index)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

            // Walk time + address
            VStack(alignment: .leading, spacing: 4) {
                if let walkTime = stop.walk_time_from_previous, walkTime != "Starting point" {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12))
                        Text(walkTime)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
                if let addr = stop.address {
                    Text(addr)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 20)

            // Description
            if let desc = stop.description {
                Text(desc)
                    .font(.system(size: 15))
                    .lineSpacing(4)
                    .padding(.horizontal, 20)
            }

            // Action links
            HStack(spacing: 16) {
                if let mapsUrl = stop.google_maps_url ?? makeGoogleMapsURL(for: stop),
                   let url = URL(string: mapsUrl) {
                    Link(destination: url) {
                        Label("Directions", systemImage: "map.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color("Radish"))
                    }
                }
                if let websiteUrl = stop.website_url, !websiteUrl.isEmpty, let url = URL(string: websiteUrl) {
                    Link(destination: url) {
                        Label("Menu", systemImage: "menucard")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color("Radish"))
                    }
                }
            }
            .padding(.horizontal, 20)

            Divider().padding(.horizontal, 20)

            // Check-off button
            Button(action: onCheckOff) {
                HStack(spacing: 8) {
                    Image(systemName: progress.completed ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(progress.completed ? .green : .secondary)
                    Text(progress.completed ? "Stop checked off! 🎉" : "Mark this stop as visited")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(progress.completed ? .green : .primary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(progress.completed ? "Visited — tap to unmark" : "Mark \(stop.name) as visited")
            .padding(.horizontal, 20)

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 20)

                TextEditor(text: $noteText)
                    .font(.system(size: 14))
                    .frame(minHeight: 80)
                    .padding(10)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 20)

                Button(action: onSaveNotes) {
                    Text(isSaving ? "Saving…" : "Save notes")
                        .font(.system(size: 13))
                        .foregroundColor(Color("Radish"))
                }
                .disabled(isSaving)
                .padding(.horizontal, 20)
            }

            // Photos
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Photos")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Add", systemImage: "camera")
                            .font(.system(size: 13))
                            .foregroundColor(Color("Radish"))
                    }
                    .onChange(of: photoItem) { _, item in
                        guard let item else { return }
                        Task {
                            if let data = try? await item.loadTransferable(type: Data.self) {
                                onUploadPhoto(data)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                if isUploading {
                    ProgressView("Uploading…")
                        .font(.system(size: 12))
                        .padding(.horizontal, 20)
                }

                if !progress.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(progress.photos, id: \.self) { url in
                                AsyncImage(url: URL(string: url)) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Rectangle().fill(Color(.secondarySystemBackground))
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

    private func makeGoogleMapsURL(for stop: TourStop) -> String? {
        let q = (stop.name + " " + (stop.address ?? ""))
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://maps.google.com/?q=\(q)"
    }
}

// MiniMapView is defined in MapViews.swift

// MARK: - Completion card
struct CompletionCardView: View {
    let tour: Tour
    var onBuildAnother: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            BrandMarkView(fontSize: 20)
                .padding(.top, 32)
            Text("You conquered today's\nTiNY FOOD TOUR!")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)
            Text("Every stop in \(tour.neighborhood), on foot.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            // Primary: build another tour
            Button {
                dismiss()
                onBuildAnother?()
            } label: {
                Text("Build another tour →")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("Primary"))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)
            .padding(.top, 4)
            // Secondary: review tour stops
            Button("Review your stops") { dismiss() }
                .font(.system(size: 14))
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
