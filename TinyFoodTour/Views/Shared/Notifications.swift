import Foundation

extension Notification.Name {
    // Posted when the user wants to restart the quiz from a fresh step 1
    // (e.g. "Build another tour →" on the post-tour recap). Handlers unwind
    // GeneratingView and reset QuizViewModel's step/answers — QuizView itself
    // stays on the nav stack so HomeView's `showQuiz` binding doesn't need to
    // change (avoids the coalesced true→false→true no-op described below).
    static let buildAnotherTour = Notification.Name("tft.buildAnotherTour")

    // Posted when the user wants to leave the generated-tour experience
    // entirely and return to HomeView (the "←" back chevron on Results).
    // Unlike `.buildAnotherTour`, this actually pops QuizView off the stack.
    static let backToHome = Notification.Name("tft.backToHome")
}
