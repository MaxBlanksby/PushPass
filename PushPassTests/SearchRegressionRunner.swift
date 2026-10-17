import Foundation

// Compile with the production models, library, search engine, and SearchEngineTests.swift.
@main
struct SearchRegressionRunner {
    static func main() throws {
        precondition(SearchEngineTests.runAllTests() == 0, "Search regression failed")
        let exercises = SearchEngineTests.sampleExercises
        func names(_ query: String) -> [String] {
            ExerciseSearchEngine.search(exercises, query: query).map(\.name)
        }
        precondition(names("bench press").first == "Bench Press")
        precondition(names("db bench") == ["Dumbbell Bench Press"])
        precondition(names("bench xyz123").isEmpty)
        precondition(names("push up") == ["Push-Up"])
        precondition(names("  \n ").count == exercises.count)
        precondition(names("!!!").count == exercises.count)
        precondition(names("bb pecs") == ["Barbell Bench Press", "Bench Press"])
        precondition(names("glutes").contains("Squat"))
        precondition(names("shoulders").contains("Overhead Press"))
        precondition(names("bnech press").contains("Bench Press"))

        let url = URL(fileURLWithPath: "LiftingLogger/Services/LiftingLogger_Exercise_Library.json")
        let document = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        let rawEntries = document["exercises"] as! [[String: Any]]
        precondition(rawEntries.count == document["exercise_count"] as! Int)
        let entries: [[String: String]] = rawEntries.map { entry in
            entry.reduce(into: [:]) { result, pair in
                if let values = pair.value as? [String] { result[pair.key] = values.joined(separator: ", ") }
                else if let value = pair.value as? String { result[pair.key] = value }
            }
        }
        precondition(ExerciseLibrary.builtInExercises.count == entries.count,
                     "Bundled library failed to load all expanded exercises")
        let library = entries.map { entry in
            Exercise(name: entry["name"]!, muscleGroup: .other, equipment: .other,
                     instructions: String(data: try! JSONSerialization.data(withJSONObject: [
                        "name": entry["name"]!, "category": entry["category"]!,
                        "primaryMuscles": entry["primary_muscles"]!,
                        "secondaryMuscles": entry["secondary_muscles"]!,
                        "equipment": entry["equipment"]!, "exerciseType": entry["exercise_type"]!,
                        "setup": entry["setup"]!, "formCues": entry["form_cues"]!
                     ]), encoding: .utf8)!)
        }
        for exercise in library {
            precondition(ExerciseSearchEngine.search(library, query: exercise.name).first?.name == exercise.name,
                         "Exact match failed: \(exercise.name)")
        }
        print("Passed additional search regressions and exact-name checks for \(library.count) library exercises.")
    }
}
