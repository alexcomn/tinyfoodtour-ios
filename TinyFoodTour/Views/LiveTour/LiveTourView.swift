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
                Text(error).foregroundColor(.secondary).padding()
            } else if let tour = vm.tour {
                mainContent(tour: tour)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .sheet(isPresented: $vm.showCompletionCard) {
            CompletionCardView(tour: vm.tour!)
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
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .bottom)
    }

    private func stopDots(tour: Tour) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<tour.stops.count, id: \.self) { i in
                Button {
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
        )
        .padding(.bottom, 20)
    }
}

// MARK: - Individual stop detail
struct StopDetailView: View {
    let stop: TourStop
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
                        Text(stop.cuisine_type + " · " + String(repeating: "$", count: max(1, stop.price_level)))
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

            // Mini map
            MiniMapView(stop: stop)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 20)

            // Walk time + address
            VStack(alignment: .leading, spacing: 4) {
                if stop.walk_time_from_previous != "Starting point" {
                    HStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12))
                        Text(stop.walk_time_from_previous)
                            .font(.system(size: 13))
                    }
                    .foregroundColor(.secondary)
                }
                Text(stop.address)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 20)

            // Description
            Text(stop.description)
                .font(.system(size: 15))
                .lineSpacing(4)
                .padding(.horizontal, 20)

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
                if !stop.website_url.isEmpty, let url = URL(string: stop.website_url) {
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
                    Text(progress.completed ? "Visited!" : "Mark as visited")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(progress.completed ? .green : .primary)
                }
            }
            .buttonStyle(.plain)
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
                    .onChange(of: photoItem) { item in
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
        let q = (stop.name + " " + stop.address)
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "https://maps.google.com/?q=\(q)"
    }
}

// MARK: - Mini map for a single stop
struct MiniMapView: View {
    let stop: TourStop
    @State private var region: MKCoordinateRegion

    init(stop: TourStop) {
        self.stop = stop
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lng),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        Map(coordinateRegion: $region, annotationItems: [stop]) { s in
            MapMarker(coordinate: CLLocationCoordinate2D(latitude: s.lat, longitude: s.lng),
                      tint: Color("Radish"))
        }
    }
}

// MARK: - Completion card
struct CompletionCardView: View {
    let tour: Tour
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 20) {
            BrandMarkView(fontSize: 20)
                .padding(.top, 32)
            Text("Tour complete! 🎉")
                .font(.system(size: 26, weight: .bold, design: .serif))
            Text("You explored \(tour.neighborhood) like a local.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Done") { dismiss() }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(Color("Radish"))
                .clipShape(Capsule())
                .padding(.top, 8)
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
