import SwiftUI

struct GeneratingView: View {
    let answers: QuizAnswers
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var vm = TourViewModel()
    @State private var navigateToResults = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
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

                    Text(vm.generatingMessage)
                        .font(.system(size: 14))
                        .foregroundColor(Color("Radish"))
                        .animation(.easeInOut(duration: 0.3), value: vm.generatingMessage)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .lightStatusBar()
        .onReceive(NotificationCenter.default.publisher(for: .buildAnotherTour)) { _ in
            dismiss()
        }
        // UIKit .fullScreen + .crossDissolve — no zoom animation, no coordinate transform,
        // guaranteed correct frame. Replaces fullScreenCover which uses iOS 26's zoom
        // animation that leaves views with a residual coordinate offset.
        .uiFullScreen(isPresented: $navigateToResults) {
            if let tour = vm.tour {
                ResultsView(tour: tour, isShared: false, generationParams: answers)
                    .environmentObject(authVM)
            } else {
                EmptyView()
            }
        }
        .task {
            await vm.generate(answers: answers)
            if vm.tour != nil {
                navigateToResults = true
            }
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            BrandMarkView(fontSize: 11)
            Text("Tour generation hit a snag")
                .font(.system(size: 15, weight: .medium))
            Text(error)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            HStack(spacing: 12) {
                Button {
                    Task {
                        await vm.generate(answers: answers)
                        if vm.tour != nil { navigateToResults = true }
                    }
                } label: {
                    Text("Try again")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color("Primary"))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                Button {
                    dismiss()
                } label: {
                    Text("Start over")
                        .font(.system(size: 14))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.2)))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
