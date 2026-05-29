import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var savedToursVM = SavedToursViewModel()
    @State private var showQuiz = false
    @State private var showAuth = false
    @State private var showProfile = false
    @State private var selectedTour: Tour?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Hero — PizzaCrust bg, matches web HomeHero layout
                    // Note: the ScrollView background is set to PizzaCrust below so
                    // the top safe area is also filled (no white bleed on overscroll)
                    VStack(alignment: .leading, spacing: 0) {
                        BrandMarkView(fontSize: 11)
                            .padding(.top, 52)
                            .padding(.bottom, 24)

                        // Eyebrow — orange tracked label (web: text-tft-orange, tracking)
                        Text("A WALKING FOOD TOUR, BUILT FOR YOU")
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1.8)
                            .foregroundColor(Color("TFTOrange"))
                            .padding(.bottom, 10)

                        // Headline — matches web "Every neighborhood is a menu."
                        Text("Every neighborhood\nis a menu.")
                            .font(.system(size: 34, weight: .bold, design: .serif))
                            .foregroundColor(Color("Foreground"))
                            .lineSpacing(2)
                            .padding(.bottom, 14)

                        // Body — matches web copy exactly
                        Text("Tell us where you are and what you like. We'll build a food tour around you: personalized stops, all on foot.")
                            .font(.system(size: 15))
                            .foregroundColor(Color("SlateMid"))
                            .lineSpacing(3)
                            .padding(.bottom, 28)

                        CTAButton(title: "Get Started →", isEnabled: true) {
                            showQuiz = true
                        }

                        Text("Works anywhere in the world")
                            .font(.system(size: 12))
                            .foregroundColor(Color("SlateMid"))
                            .padding(.top, 8)
                            .padding(.bottom, 48)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .background(Color("PizzaCrust"))

                    // Past tours section
                    if !savedToursVM.savedTours.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Past Tours")
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundColor(Color("TFTSlate"))
                                .padding(.horizontal, 20)
                                .padding(.top, 28)

                            ForEach(savedToursVM.savedTours) { tour in
                                Button {
                                    selectedTour = tour
                                } label: {
                                    SavedTourRow(tour: tour)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom, 32)
                    } else if savedToursVM.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if authVM.currentUser != nil {
                            showProfile = true
                        } else {
                            showAuth = true
                        }
                    } label: {
                        Image(systemName: authVM.currentUser != nil ? "person.circle.fill" : "person.circle")
                            .foregroundColor(Color("Primary"))
                    }
                }
            }
            .background(Color("PizzaCrust"))  // fills top overscroll area
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showQuiz) {
                QuizView()
            }
            .sheet(isPresented: $showAuth) {
                AuthView()
                    .environmentObject(authVM)
            }
            .sheet(isPresented: $showProfile) {
                ProfileView()
                    .environmentObject(authVM)
            }
            .sheet(item: $selectedTour) { tour in
                ResultsView(tour: tour, isShared: true, generationParams: nil)
                    .environmentObject(authVM)
            }
        }
        .darkStatusBar()
        .task {
            await savedToursVM.load()
        }
    }
}

struct SavedTourRow: View {
    let tour: Tour

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(tour.neighborhood)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Text("\(tour.stops.count) stops · \(tour.vibe.first ?? "")")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(.systemBackground))
        Divider().padding(.leading, 20)
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
