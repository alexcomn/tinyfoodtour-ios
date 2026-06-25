import SwiftUI

// MARK: - ReactionBar
// Horizontal scrollable row of emoji reaction pills.
// Pass the shared ReactionsViewModel from ResultsView; stopIndex scopes the display
// (nil = tour-level reaction, Int = reaction for that stop index).

private let kReactionEmojis = ["🔥", "❤️", "😋", "⭐️", "🙌"]

struct ReactionBar: View {
    @ObservedObject var vm: ReactionsViewModel
    let stopIndex: Int?

    var body: some View {
        let grouped = vm.grouped(forStop: stopIndex)
        // Start with emojis that have reactions (sorted by count), then fill remaining slots
        // from the default set so there are always 5 options visible.
        let pills: [String] = {
            var result = grouped.map(\.emoji)
            for e in kReactionEmojis where !result.contains(e) { result.append(e) }
            return Array(result.prefix(5))
        }()

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(pills, id: \.self) { emoji in
                    let entry = grouped.first { $0.emoji == emoji }
                    ReactionPill(
                        emoji: emoji,
                        count: entry?.count ?? 0,
                        userReacted: entry?.userReacted ?? false
                    ) {
                        if Session.shared.isSignedIn {
                            Task { await vm.toggle(emoji: emoji, stopIndex: stopIndex) }
                        } else {
                            ToastManager.shared.show("Sign in to react", style: .info)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Pill

private struct ReactionPill: View {
    let emoji: String
    let count: Int
    let userReacted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text(emoji).font(.system(size: 14))
                if count > 0 {
                    Text("\(count)")
                        .scaledFont(size: 11, weight: .medium)
                        .foregroundColor(userReacted ? Color("Primary") : Color("SlateMid"))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                userReacted
                    ? Color("Primary").opacity(0.08)
                    : Color("CreamDark").opacity(0.6)
            )
            .overlay(
                Capsule().stroke(
                    userReacted ? Color("Primary").opacity(0.4) : Color.primary.opacity(0.12),
                    lineWidth: 1
                )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: userReacted)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: count)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        ReactionBar(vm: {
            let vm = ReactionsViewModel(shareToken: "preview")
            return vm
        }(), stopIndex: nil)
        ReactionBar(vm: {
            let vm = ReactionsViewModel(shareToken: "preview")
            return vm
        }(), stopIndex: 0)
    }
    .padding()
    .background(Color("Cream"))
}
