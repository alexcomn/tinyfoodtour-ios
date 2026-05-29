import Foundation

struct QuizTreeOption: Codable {
    let label: String
    let subtitle: String?
    let next_step: String?
}

struct QuizTreeStep: Codable, Identifiable {
    var id: String { step_key }
    let step_key: String
    let parent_step_key: String?
    let question: String
    let hint: String?
    let step_type: String // "single_select" | "multi_select"
    let options: [QuizTreeOption]
    let sort_order: Int
}

// The ordered list of step keys for a given set of answers
struct QuizSequenceBuilder {
    let stepMap: [String: QuizTreeStep]

    func buildSequence(answers: QuizAnswers) -> [String] {
        guard !stepMap.isEmpty else { return [] }

        var seq = ["neighborhood", "meal_type"]

        // Determine branch after meal_type
        let mealStep = stepMap["meal_type"]
        let nextAfterMeal = mealStep?.options.first(where: { $0.label == answers.mealType })?.next_step

        if let branch = nextAfterMeal, stepMap[branch] != nil {
            seq.append(branch)
        } else {
            seq.append("vibe")
        }

        // Cuisine variant — only after vibe branch
        if nextAfterMeal == "vibe" || nextAfterMeal == nil {
            if answers.mealType == "Breakfast", stepMap["cuisines_breakfast"] != nil {
                seq.append("cuisines_breakfast")
            } else {
                seq.append("cuisines")
            }
        }

        seq += ["dietary", "budget", "walk_distance"]
        return seq
    }
}
