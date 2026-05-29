import SwiftUI

struct QuizView: View {
    @StateObject private var vm = QuizViewModel()
    @EnvironmentObject var authVM: AuthViewModel
    @State private var navigateToGenerating = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            if vm.isLoadingTree {
                loadingView
            } else if let error = vm.treeError {
                errorView(error)
            } else {
                quizContent
            }
        }
        .navigationBarBackButtonHidden(true)
        .darkStatusBar()
        .navigationDestination(isPresented: $navigateToGenerating) {
            GeneratingView(answers: vm.answers)
        }
        .task {
            await vm.loadTree()
            if let userId = authVM.currentUser?.id {
                await vm.loadUserHistory(userId: userId)
            }
            await vm.geolocate()
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .tint(Color("Radish"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            CTAButton(title: "Try again", isEnabled: true) {
                Task { await vm.loadTree() }
            }
        }
        .padding(32)
    }

    private var quizContent: some View {
        VStack(spacing: 0) {
            // Top bar
            VStack(spacing: 0) {
                BrandMarkView()
                    .padding(.top, 12)
                    .padding(.bottom, 16)

                QuizProgressBar(current: vm.stepIndex, total: vm.totalSteps)
                    .padding(.horizontal, 20)

                Text("Step \(vm.stepIndex + 1) of \(vm.totalSteps)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
                    .padding(.bottom, 16)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    Text(vm.currentTitle)
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(Color("Foreground"))
                        .padding(.horizontal, 20)
                        .padding(.top, 4)

                    if !vm.currentHint.isEmpty {
                        Text(vm.currentHint)
                            .font(.system(size: 13))
                            .italic()
                            .foregroundColor(Color("SlateMid"))
                            .padding(.horizontal, 20)
                            .padding(.bottom, 4)
                    }

                    if vm.currentStepKey == "neighborhood" {
                        NeighborhoodStepView(vm: vm)
                            .padding(.horizontal, 20)
                    } else {
                        optionGrid
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 100)
            }

            // Sticky footer nav
            bottomNav
        }
        .background(Color("Cream"))
        .ignoresSafeArea(edges: .bottom)
    }

    private var optionGrid: some View {
        FlowLayout(spacing: 8) {
            ForEach(vm.currentOptions, id: \.self) { option in
                PillButton(label: option, isSelected: vm.isSelected(option)) {
                    vm.toggleOption(option)
                    // Auto-advance single-select (non-neighborhood) steps
                    if vm.currentDbStep?.step_type != "multi_select" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            advance()
                        }
                    }
                }
            }
        }
    }

    private var bottomNav: some View {
        HStack {
            Button {
                let shouldDismiss = vm.goBack()
                if shouldDismiss { dismiss() }
            } label: {
                Text("← Back")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            CTAButton(
                title: vm.stepIndex == vm.totalSteps - 1 ? "Build my tour →" : "Next →",
                isEnabled: vm.canAdvance
            ) {
                advance()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(
            Color(.systemBackground)
                .shadow(color: .black.opacity(0.06), radius: 8, y: -2)
                .ignoresSafeArea(edges: .bottom)
        )
        .padding(.bottom, max(20, UIApplication.safeAreaBottom))
    }

    private func advance() {
        guard vm.canAdvance else { return }
        let done = vm.goNext()
        if done { navigateToGenerating = true }
    }
}

// MARK: - Flow layout for pill buttons
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var height: CGFloat = 0
        var row: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if row + size.width > width, row > 0 {
                height += rowHeight + spacing
                row = 0
                rowHeight = 0
            }
            row += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        height += rowHeight
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview {
    NavigationStack {
        QuizView()
            .environmentObject(AuthViewModel())
    }
}
