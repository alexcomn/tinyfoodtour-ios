import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @StateObject private var vm = ProfileViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        BrandMarkView(fontSize: 11)
                            .padding(.bottom, 8)
                        Text(authVM.currentUser?.email ?? "")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(Color("Foreground"))
                        HStack(spacing: 16) {
                            statPill(value: vm.completedToursCount, label: "tours completed")
                            statPill(value: vm.favoritesCount, label: "favourites")
                        }
                        .padding(.top, 6)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color("PizzaCrust"))

                    // Saved Tours
                    if !vm.savedTours.isEmpty {
                        sectionHeader("Saved Tours")
                        ForEach(vm.savedTours) { tour in
                            TourListRow(tour: tour)
                        }
                        Divider().padding(.top, 8)
                    }

                    // Favourites
                    if !vm.favorites.isEmpty {
                        sectionHeader("Favourites")
                        ForEach(vm.favorites) { spot in
                            FavouriteRow(spot: spot)
                        }
                        Divider().padding(.top, 8)
                    }

                    if vm.isLoading {
                        ProgressView()
                            .tint(Color("Radish"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    }

                    // Sign out
                    Button {
                        authVM.signOut()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign out")
                        }
                        .font(.system(size: 15))
                        .foregroundColor(Color("Radish"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)
                }
            }
            .background(Color("Cream"))
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Color("Primary"))
                }
            }
        }
        .task {
            if let userId = authVM.currentUser?.id {
                await vm.load(userId: userId)
            }
        }
    }

    private func statPill(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold, design: .serif))
                .foregroundColor(Color("Primary"))
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Color("SlateMid"))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color("SlateMid"))
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 8)
    }
}

// MARK: - Saved tour row
struct TourListRow: View {
    let tour: ProfileTour
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(tour.neighborhood)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Color("Foreground"))
                Text("\(tour.stopCount) stops")
                    .font(.system(size: 12))
                    .foregroundColor(Color("SlateMid"))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Color("SlateMid"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        Divider().padding(.leading, 20)
    }
}

// MARK: - Favourite spot row
struct FavouriteRow: View {
    let spot: FavouriteSpot
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.fill")
                .font(.system(size: 13))
                .foregroundColor(Color("Radish"))
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(spot.name)
                    .font(.system(size: 15))
                    .foregroundColor(Color("Foreground"))
                if let neighbourhood = spot.neighborhood {
                    Text(neighbourhood)
                        .font(.system(size: 12))
                        .foregroundColor(Color("SlateMid"))
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        Divider().padding(.leading, 56)
    }
}
