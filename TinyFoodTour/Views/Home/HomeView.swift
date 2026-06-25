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
                            .scaledFont(size: 10, weight: .medium)
                            .tracking(1.8)
                            .foregroundColor(Color("TFTOrange"))
                            .padding(.bottom, 10)

                        // Headline — matches web "Every neighborhood is a menu."
                        Text("Every neighborhood\nis a menu.")
                            .font(TFTFont.heading(34))
                            .foregroundColor(Color("Foreground"))
                            .lineSpacing(2)
                            .padding(.bottom, 14)

                        // Body — matches web copy exactly
                        Text("Tell us where you are and what you like. We'll build a food tour around you: personalized stops, all on foot.")
                            .scaledFont(size: 15)
                            .foregroundColor(Color("SlateMid"))
                            .lineSpacing(3)
                            .padding(.bottom, 28)

                        CTAButton(title: "Get Started →", isEnabled: true) {
                            showQuiz = true
                        }

                        Text("Works anywhere in the world")
                            .scaledFont(size: 12)
                            .foregroundColor(Color("SlateMid"))
                            .padding(.top, 8)
                            .padding(.bottom, 48)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .background(Color("PizzaCrust"))

                    // Past tours section
                    if !savedToursVM.savedTours.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            // Section header
                            HStack(alignment: .firstTextBaseline) {
                                Text("Past Tours")
                                    .font(TFTFont.heading(20))
                                    .foregroundColor(Color("TFTSlate"))
                                Spacer()
                                Button { showProfile = true } label: {
                                    Text("See all →")
                                        .scaledFont(size: 13)
                                        .foregroundColor(Color("Primary"))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 28)

                            // Horizontal card scroll
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(savedToursVM.savedTours.prefix(8)) { tour in
                                        PastTourCard(tour: tour)
                                            .onTapGesture { selectedTour = tour }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 36)
                        .background(Color("Cream"))
                    } else if savedToursVM.isLoading {
                        ProgressView().tint(Color("Primary"))
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
        .onAppear {
            Task { await savedToursVM.load() }
        }
        .task {
            await savedToursVM.load()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToProfile)) { _ in
            // Brief delay lets QuizView's dismiss() animation complete first
            // so the profile sheet presents onto HomeView, not a departing nav stack.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if authVM.currentUser != nil {
                    showProfile = true
                } else {
                    showAuth = true
                }
            }
        }
        // Note: "Build another tour →" no longer needs a handler here —
        // QuizView resets itself in place (see QuizView's .buildAnotherTour
        // handler) without leaving HomeView's nav stack, so `showQuiz`
        // never needs to change. ".backToHome" (the Results back chevron)
        // is handled by QuizView's own dismiss(), which pops it off the
        // stack and naturally reveals HomeView underneath.
    }
}

struct PastTourCard: View {
    let tour: Tour

    private var shortDate: String {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: tour.created_at)
            ?? ISO8601DateFormatter().date(from: tour.created_at)
        guard let date else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return fmt.string(from: date)
    }

    private var vibeLabel: String { tour.vibe.first ?? "" }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── Stop-colour segment bar ─────────────────────────────
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(tour.stops.prefix(5).enumerated()), id: \.offset) { i, _ in
                        StopLabel.color(index: i)
                            .frame(width: geo.size.width / CGFloat(min(tour.stops.count, 5)),
                                   height: 5)
                            .clipShape(Capsule())
                    }
                }
            }
            .frame(height: 5)
            .padding(.horizontal, 16)
            .padding(.top, 16)

            // ── Neighbourhood + date ────────────────────────────────
            HStack {
                Text(tour.neighborhood.uppercased())
                    .scaledFont(size: 9, weight: .semibold)
                    .tracking(1.4)
                    .foregroundColor(Color("Primary"))
                Spacer()
                Text(shortDate)
                    .scaledFont(size: 11)
                    .foregroundColor(Color("SlateMid"))
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)

            // ── Tour title ──────────────────────────────────────────
            Text(tour.displayTitle)
                .font(TFTFont.heading(17))
                .foregroundColor(Color("TFTSlate"))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .padding(.top, 6)

            Spacer(minLength: 8)

            // ── Stop preview ────────────────────────────────────────
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(tour.stops.prefix(3).enumerated()), id: \.offset) { i, stop in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(StopLabel.color(index: i))
                            .frame(width: 5, height: 5)
                        Text(stop.name)
                            .scaledFont(size: 11)
                            .foregroundColor(Color("SlateMid"))
                            .lineLimit(1)
                    }
                }
                if tour.stops.count > 3 {
                    Text("+\(tour.stops.count - 3) more")
                        .scaledFont(size: 10)
                        .foregroundColor(Color("SlateMid").opacity(0.6))
                        .padding(.leading, 11)
                }
            }
            .padding(.horizontal, 16)

            // ── Footer ──────────────────────────────────────────────
            Divider()
                .padding(.top, 12)

            HStack {
                HStack(spacing: 4) {
                    Text("\(tour.stops.count) stops")
                    if !vibeLabel.isEmpty {
                        Text("·").foregroundColor(Color("SlateMid").opacity(0.4))
                        Text(vibeLabel)
                            .lineLimit(1)
                    }
                }
                .scaledFont(size: 11)
                .foregroundColor(Color("SlateMid"))

                Spacer()

                Image(systemName: "arrow.right")
                    .scaledFont(size: 10)
                    .foregroundColor(Color("Primary").opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 256, height: 196)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
