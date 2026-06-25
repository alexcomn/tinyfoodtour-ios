import SwiftUI

struct GeneratingView: View {
    let answers: QuizAnswers
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = TourViewModel()
    @State private var showResults = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        // Show ResultsView inline (same NavigationStack level, same coordinate space).
        // Any presentation mechanism in iOS 26 — fullScreenCover, UIKit modal,
        // animated or not — carries a residual coordinate transform that shifts
        // content beyond the viewport. Inline conditional rendering avoids all of it.
        Group {
            if showResults, let tour = vm.tour {
                ResultsView(
                    tour: tour,
                    isShared: false,
                    generationParams: answers,
                    onBack: {
                        // Unwind the whole stack back to HomeView
                        NotificationCenter.default.post(name: .backToHome, object: nil)
                    }
                )
                .environmentObject(authVM)
            } else {
                generatingContent
            }
        }
        // Attached at the top level (not just `generatingContent`) so these
        // fire regardless of whether Results/Live Tour is currently showing.
        .onReceive(NotificationCenter.default.publisher(for: .buildAnotherTour)) { _ in
            dismiss()
        }
        .onReceive(NotificationCenter.default.publisher(for: .backToHome)) { _ in
            dismiss()
        }
    }

    private var generatingContent: some View {
        ZStack {
            Color("Cream").ignoresSafeArea()

            if let error = vm.generationError {
                errorView(error)
            } else {
                VStack(spacing: 20) {
                    BrandMarkView(fontSize: 11)

                    ProgressView()
                        .tint(Color("Radish"))
                        .scaleEffect(1.2)

                    // Fixed-height container prevents other elements from
                    // jumping when the message text changes length or wraps.
                    ZStack {
                        Text(vm.generatingMessage)
                            .scaledFont(size: 14)
                            .foregroundColor(Color("Radish"))
                            .multilineTextAlignment(.center)
                            .id(vm.generatingMessage)
                            .transition(.opacity)
                    }
                    .frame(height: 44)
                    .animation(.easeInOut(duration: 0.35), value: vm.generatingMessage)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .lightStatusBar()
        .task {
            await vm.generate(answers: answers)
            if vm.tour != nil { showResults = true }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            BrandMarkView(fontSize: 11)
            Text("Tour generation hit a snag")
                .scaledFont(size: 15, weight: .medium)
            Text(error)
                .scaledFont(size: 13)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button {
                    Task {
                        await vm.generate(answers: answers)
                        if vm.tour != nil { showResults = true }
                    }
                } label: {
                    Text("Try again")
                        .scaledFont(size: 14, weight: .medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button { dismiss() } label: {
                    Text("Start over")
                        .scaledFont(size: 14)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
