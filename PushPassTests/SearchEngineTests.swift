import Foundation

/// Test suite for search engine - standalone, no XCTest needed
enum SearchEngineTests {
    
    // MARK: - Test Data
    
    static func createInstructions(primary: String, secondary: String) -> String {
        let details = ExerciseDetails(
            name: "",
            category: "",
            primaryMuscles: primary,
            secondaryMuscles: secondary,
            equipment: "",
            exerciseType: "",
            setup: "",
            formCues: ""
        )
        guard let data = try? JSONEncoder().encode(details),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }
    
    static var sampleExercises: [Exercise] {
        [
            // Chest
            Exercise(name: "Barbell Bench Press", muscleGroup: .chest, equipment: .barbell, instructions: createInstructions(primary: "Chest", secondary: "Triceps")),
            Exercise(name: "Dumbbell Bench Press", muscleGroup: .chest, equipment: .dumbbell, instructions: createInstructions(primary: "Chest", secondary: "Triceps")),
            Exercise(name: "Push-Up", muscleGroup: .chest, equipment: .bodyweight, instructions: createInstructions(primary: "Chest", secondary: "Triceps")),
            Exercise(name: "Bench Press", muscleGroup: .chest, equipment: .barbell, instructions: createInstructions(primary: "Chest", secondary: "Triceps")),
            
            // Back
            Exercise(name: "Romanian Deadlift", muscleGroup: .hamstrings, equipment: .barbell, instructions: createInstructions(primary: "Hamstrings", secondary: "Glutes")),
            Exercise(name: "Single Leg Romanian Deadlift", muscleGroup: .hamstrings, equipment: .dumbbell, instructions: createInstructions(primary: "Hamstrings", secondary: "Glutes")),
            Exercise(name: "Dumbbell Row", muscleGroup: .back, equipment: .dumbbell, instructions: createInstructions(primary: "Latissimus", secondary: "Biceps")),
            Exercise(name: "Pull-Up", muscleGroup: .back, equipment: .bodyweight, instructions: createInstructions(primary: "Latissimus", secondary: "Biceps")),
            
            // Shoulders
            Exercise(name: "Overhead Press", muscleGroup: .shoulders, equipment: .barbell, instructions: createInstructions(primary: "Deltoids", secondary: "Triceps")),
            Exercise(name: "Dumbbell Shoulder Press", muscleGroup: .shoulders, equipment: .dumbbell, instructions: createInstructions(primary: "Deltoids", secondary: "Triceps")),
            
            // Legs
            Exercise(name: "Squat", muscleGroup: .quadriceps, equipment: .barbell, instructions: createInstructions(primary: "Quadriceps", secondary: "Glutes")),
            Exercise(name: "Bulgarian Split Squat", muscleGroup: .quadriceps, equipment: .dumbbell, instructions: createInstructions(primary: "Quadriceps", secondary: "Glutes")),
            
            // Arms
            Exercise(name: "Barbell Curl", muscleGroup: .biceps, equipment: .barbell, instructions: createInstructions(primary: "Biceps", secondary: "")),
            Exercise(name: "Dumbbell Curl", muscleGroup: .biceps, equipment: .dumbbell, instructions: createInstructions(primary: "Biceps", secondary: "")),
            Exercise(name: "Tricep Pushdown", muscleGroup: .triceps, equipment: .cable, instructions: createInstructions(primary: "Triceps", secondary: "")),
            
            // Core
            Exercise(name: "Plank", muscleGroup: .core, equipment: .bodyweight, instructions: createInstructions(primary: "Core", secondary: "")),
            Exercise(name: "Crunch", muscleGroup: .core, equipment: .bodyweight, instructions: createInstructions(primary: "Core", secondary: ""))
        ]
    }
    
    // MARK: - Test Helpers
    
    private static var failureCount = 0
    
    private static func assertFalse(_ condition: Bool, _ message: String) {
        if condition {
            print("❌ FAILED: \(message)")
            failureCount += 1
        }
    }
    
    private static func assertEqual<T: Equatable>(_ lhs: T?, _ rhs: T?, _ message: String) {
        if lhs != rhs {
            print("❌ FAILED: \(message) - Expected \(String(describing: rhs)), got \(String(describing: lhs))")
            failureCount += 1
        }
    }
    
    private static func assertTrue(_ condition: Bool, _ message: String) {
        if !condition {
            print("❌ FAILED: \(message)")
            failureCount += 1
        }
    }
    
    // MARK: - Test Methods
    
    static func testExactNameMatch() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "Squat")
        assertFalse(results.isEmpty, "Should find exercises")
        assertEqual(results.first?.name, "Squat", "Exact match should be first")
    }
    
    static func testCaseInsensitiveMatch() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "squat")
        assertFalse(results.isEmpty, "Should find exercises")
        assertEqual(results.first?.name, "Squat", "Case insensitive match should work")
    }
    
    static func testBarbellAbbreviation() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "bb bench")
        assertFalse(results.isEmpty, "Should find barbell bench exercises")
        assertTrue(results.contains { $0.name.contains("Barbell Bench") }, "Should match barbell bench press")
    }
    
    static func testDumbbellAbbreviation() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "db row")
        assertFalse(results.isEmpty, "Should find dumbbell row")
        assertEqual(results.first?.name, "Dumbbell Row", "Should match dumbbell row")
    }
    
    static func testOverheadPressAbbreviation() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "ohp")
        assertFalse(results.isEmpty, "Should find overhead press")
        assertEqual(results.first?.name, "Overhead Press", "OHP should match Overhead Press")
    }
    
    static func testRomanianDeadliftAbbreviation() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "rdl")
        assertFalse(results.isEmpty, "Should find Romanian Deadlift")
        assertTrue(results.contains { $0.name.contains("Romanian Deadlift") }, "RDL should match Romanian Deadlift")
    }
    
    static func testPecsSearchesChest() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "pecs")
        assertFalse(results.isEmpty, "Should find chest exercises")
    }
    
    static func testDeltsSearchesShoulders() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "delts")
        assertFalse(results.isEmpty, "Should find shoulder exercises")
    }
    
    static func testTypoInExerciseName() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "bnech")
        assertFalse(results.isEmpty, "Should find bench press with typo")
        assertTrue(results.contains { $0.name.contains("Bench") }, "Fuzzy matching should handle 'bnech' -> 'bench'")
    }
    
    static func testOutOfOrderTokens() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "press bench")
        assertFalse(results.isEmpty, "Should find bench press even with reversed words")
        assertTrue(results.contains { $0.name.contains("Bench Press") }, "Should match bench press")
    }
    
    static func testEmptyQuery() {
        let results = ExerciseSearchEngine.search(sampleExercises, query: "")
        assertEqual(results.count, sampleExercises.count, "Empty query should return all exercises")
    }
    
    // MARK: - Run All Tests
    
    @discardableResult
    static func runAllTests() -> Int {
        print("🧪 Running Search Engine Tests...\n")
        
        failureCount = 0
        let tests: [(String, () -> Void)] = [
            ("Exact name match", testExactNameMatch),
            ("Case insensitive match", testCaseInsensitiveMatch),
            ("Barbell abbreviation", testBarbellAbbreviation),
            ("Dumbbell abbreviation", testDumbbellAbbreviation),
            ("Overhead press abbreviation", testOverheadPressAbbreviation),
            ("Romanian deadlift abbreviation", testRomanianDeadliftAbbreviation),
            ("Pecs searches chest", testPecsSearchesChest),
            ("Delts searches shoulders", testDeltsSearchesShoulders),
            ("Typo in exercise name", testTypoInExerciseName),
            ("Out of order tokens", testOutOfOrderTokens),
            ("Empty query", testEmptyQuery)
        ]
        
        var passedCount = 0
        
        for (name, test) in tests {
            let beforeFailures = failureCount
            print("Testing: \(name)...")
            test()
            if failureCount == beforeFailures {
                passedCount += 1
                print("✅ PASSED\n")
            } else {
                print("")
            }
        }
        
        let failedCount = tests.count - passedCount
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("Tests completed: \(passedCount) passed, \(failedCount) failed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        return failureCount
    }
}
