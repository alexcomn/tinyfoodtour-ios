import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var savedToursVM = SavedToursViewModel()
    @State private var showQuiz = false
    @State private var showAuth = false
    @State private var selectedTour: Tour?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Header — bg-pizza-crust with serif headline, matches web HomeHero
                    VStack(spacing: 0) {
                        BrandMarkView(fontSize: 22)
                            .padding(.top, 52)
                            .padding(.bottom, 20)

                        Text("Your neighborhood,\none bite at a time.")
                            .font(.system(size: 30, weight: .bold, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color("Radish"))
                            .padding(.horizontal, 28)
                            .padding(.bottom, 10)

                        Text("Answer a few questions and we'll build\nyou a personalized food tour.")
                            .font(.system(size: 15))
                            .foregroundColor(Color("SlateMid"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 28)

                        CTAButton(title: "Start a Tour →", isEnabled: true) {
                            showQuiz = true
                        }
                        .padding(.bottom, 48)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color("PizzaCrust"))

                    Divider()

                    // Past tours section
                    if !savedToursVM.savedTours.isEmpty {
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
                            // show profile sheet
                        } else {
                            showAuth = true
                        }
                    } label: {
                        Image(systemName: authVM.currentUser != nil ? "person.circle.fill" : "person.circle")
                            .foregroundColor(Color("Radish"))
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $showQuiz) {
                QuizView()
            }
            .sheet(isPresented: $showAuth) {
                AuthView()
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
