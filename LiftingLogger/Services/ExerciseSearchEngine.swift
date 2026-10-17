import Foundation

/// Advanced exercise search engine with fuzzy matching, abbreviation handling, and relevance scoring
enum ExerciseSearchEngine {

    // MARK: - Public API

    /// Searches exercises with advanced fuzzy matching, abbreviation expansion, and relevance scoring
    /// - Parameters:
    ///   - exercises: Array of exercises to search
    ///   - searchText: User's search query
    /// - Returns: Sorted array of exercises by relevance (highest score first)
    static func search(_ exercises: [Exercise], query searchText: String) -> [Exercise] {
        let results = searchWithScores(exercises, query: searchText)
        return results.map(\.exercise)
    }

    /// Searches exercises and returns them with their relevance scores
    /// Useful for debugging and understanding the ranking
    /// - Parameters:
    ///   - exercises: Array of exercises to search
    ///   - searchText: User's search query
    /// - Returns: Sorted array of (exercise, score) tuples
    static func searchWithScores(_ exercises: [Exercise], query searchText: String) -> [(exercise: Exercise, score: Int)] {
        let query = normalize(searchText)

        // Return all exercises if query is empty
        guard !query.isEmpty else {
            return exercises.map { ($0, 0) }
        }

        // Expand abbreviations and muscle group synonyms
        let expandedQuery = expandAbbreviations(query)
        let muscleGroupQuery = expandMuscleGroupSynonyms(expandedQuery)

        // Tokenize the query for multi-word matching
        let queryTokens = tokenize(muscleGroupQuery)

        // Score each exercise and filter by minimum score
        let scoredExercises: [(exercise: Exercise, score: Int)] = exercises.compactMap { exercise in
            let score = calculateRelevanceScore(
                for: exercise,
                originalQuery: query,
                expandedQuery: muscleGroupQuery,
                tokens: queryTokens
            )

            // Only return exercises with a score > 0
            return score > 0 ? (exercise, score) : nil
        }

        // Sort by score (highest first), then alphabetically by name
        return scoredExercises
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }
                return lhs.exercise.name.localizedCaseInsensitiveCompare(rhs.exercise.name) == .orderedAscending
            }
    }

    /// Returns a human-readable explanation of how the query was processed
    /// - Parameter query: The search query
    /// - Returns: String explaining the query expansion
    static func explainQuery(_ query: String) -> String {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Empty query - returns all exercises" }

        let afterAbbrev = expandAbbreviations(trimmed)
        let afterMuscle = expandMuscleGroupSynonyms(afterAbbrev)
        let tokens = tokenize(afterMuscle)

        var explanation = "Original query: \"\(trimmed)\"\n"

        if afterAbbrev != trimmed.lowercased() {
            explanation += "After abbreviation expansion: \"\(afterAbbrev)\"\n"
        }

        if afterMuscle != afterAbbrev {
            explanation += "After muscle group expansion: \"\(afterMuscle)\"\n"
        }

        explanation += "Search tokens: [\(tokens.map { "\"\($0)\"" }.joined(separator: ", "))]"

        return explanation
    }

    // MARK: - Abbreviation Mapping

    private static let abbreviationMap: [String: String] = [
        // Equipment abbreviations
        "bb": "barbell",
        "db": "dumbbell",

        // Exercise abbreviations
        "ohp": "overhead press",
        "rdl": "romanian deadlift",
        "slrdl": "single leg romanian deadlift",
        "bp": "bench press",
        "dl": "deadlift",

        // Common variations
        "t-bar": "t bar",
        "ez bar": "ez-bar",
        "ezbar": "ez-bar"
    ]

    private static let muscleGroupSynonyms: [String: String] = [
        // Chest
        "pecs": "chest",
        "pec": "chest",
        "pectorals": "chest",

        // Biceps
        "bis": "biceps",
        "bi": "biceps",

        // Triceps
        "tris": "triceps",
        "tri": "triceps",

        // Shoulders
        "delts": "deltoids",
        "delt": "deltoids",
        "shoulders": "deltoids",
        "shoulder": "deltoids",

        // Legs
        "quads": "quadriceps",
        "quad": "quadriceps",
        "glutes": "gluteus",
        "gluteal": "gluteus",
        "glute": "gluteus",
        "hams": "hamstrings",
        "ham": "hamstrings",

        // Back
        "lats": "latissimus",
        "lat": "latissimus",

        // Arms
        "arms": "biceps triceps",
        "arm": "biceps triceps"
    ]

    // MARK: - Query Expansion

    /// Expands common abbreviations in the query
    private static func expandAbbreviations(_ query: String) -> String {
        let lowercased = query.lowercased()
        var expanded = lowercased

        // Replace abbreviations with their full forms
        for (abbreviation, fullForm) in abbreviationMap.sorted(by: { $0.key < $1.key }) {
            // Match whole words only (with word boundaries)
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: abbreviation))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(expanded.startIndex..., in: expanded)
                expanded = regex.stringByReplacingMatches(
                    in: expanded,
                    range: range,
                    withTemplate: fullForm
                )
            }
        }

        return expanded
    }

    /// Expands muscle group synonyms in the query
    private static func expandMuscleGroupSynonyms(_ query: String) -> String {
        tokenize(query).map { muscleGroupSynonyms[$0] ?? $0 }.joined(separator: " ")
    }

    // MARK: - Tokenization

    /// Splits query into individual tokens (words)
    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }.joined(separator: " ")
    }

    private static func tokenize(_ text: String) -> [String] {
        normalize(text)
            .components(separatedBy: .whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
    }

    // MARK: - Relevance Scoring

    /// Calculates relevance score for an exercise based on the search query
    /// - Returns: Score (higher is better, 0 means no match)
    private static func calculateRelevanceScore(
        for exercise: Exercise,
        originalQuery: String,
        expandedQuery: String,
        tokens: [String]
    ) -> Int {
        var score = 0
        let exerciseName = normalize(exercise.name)
        let originalQueryLower = normalize(originalQuery)
        let expandedQueryLower = normalize(expandedQuery)

        // Get exercise details for extended matching
        let details = ExerciseLibrary.details(for: exercise)
        let primaryMuscles = expandMuscleGroupSynonyms(normalize(details?.primaryMuscles ?? ""))
        let secondaryMuscles = expandMuscleGroupSynonyms(normalize(details?.secondaryMuscles ?? ""))
        let equipment = normalize(exercise.equipment.rawValue + " " + (details?.equipment ?? ""))
        let muscleGroup = expandMuscleGroupSynonyms(normalize(exercise.muscleGroup.rawValue))

        // Weight 10: Exact match or prefix match on Exercise Name
        if exerciseName == originalQueryLower || exerciseName == expandedQueryLower {
            score += 30
        } else if exerciseName.hasPrefix(originalQueryLower) || exerciseName.hasPrefix(expandedQueryLower) {
            score += 10
        }

        // Weight 7: Match found in primary or secondary muscles (acts as "aliases")
        if primaryMuscles.contains(expandedQueryLower) ||
           secondaryMuscles.contains(expandedQueryLower) {
            score += 7
        }

        // Weight 5: Match found in muscle group or equipment
        if muscleGroup.contains(expandedQueryLower) ||
           equipment.contains(expandedQueryLower) {
            score += 5
        }

        // Token-based matching (allows out-of-order words)
        var tokenMatchCount = 0
        for token in tokens {
            // Check if token matches anywhere in the exercise name
            if expandMuscleGroupSynonyms(exerciseName).contains(token) {
                tokenMatchCount += 1
                score += 3
            } else if primaryMuscles.contains(token) || secondaryMuscles.contains(token) {
                tokenMatchCount += 1
                score += 2
            } else if muscleGroup.contains(token) || equipment.contains(token) {
                tokenMatchCount += 1
                score += 1
            }
        }

        // Every query term must match; equipment alone must not admit unrelated exercises.
        let searchableName = expandMuscleGroupSynonyms(exerciseName)
        guard tokens.allSatisfy({ token in
            searchableName.contains(token) || primaryMuscles.contains(token) ||
            secondaryMuscles.contains(token) || muscleGroup.contains(token) ||
            equipment.contains(token) || fuzzyMatch(token, in: searchableName)
        }) else { return 0 }
        if tokenMatchCount < tokens.count { score += 1 }

        // Bonus for matching all tokens (complete match with out-of-order support)
        if !tokens.isEmpty && tokenMatchCount == tokens.count {
            score += 5
        }

        // Weight 3: Fuzzy / typo-corrected match on exercise name
        if score == 0 || score < 5 {
            // Apply fuzzy matching as a fallback or boost
            if fuzzyMatch(originalQueryLower, in: exerciseName) ||
               fuzzyMatch(expandedQueryLower, in: exerciseName) {
                score += 3
            } else {
                // Check fuzzy match for individual tokens
                for token in tokens {
                    if fuzzyMatch(token, in: exerciseName) {
                        score += 1
                    }
                }
            }
        }

        // Substring matching for simple contains check
        if score > 0 {
            // Boost score if query is a substring of the name
            if exerciseName.contains(originalQueryLower) {
                score += 2
            }
        }

        return score
    }

    // MARK: - Fuzzy Matching

    /// Performs fuzzy matching with Levenshtein Distance (max 1-2 edits)
    /// - Parameters:
    ///   - query: Search string
    ///   - target: String to search in
    /// - Returns: True if fuzzy match found
    private static func fuzzyMatch(_ query: String, in target: String) -> Bool {
        // Don't fuzzy match very short queries
        guard query.count >= 3 else {
            return target.contains(query)
        }

        // Check if query exists as substring
        if target.contains(query) {
            return true
        }

        // Split target into words and check fuzzy match against each
        let targetWords = tokenize(target)

        for word in targetWords {
            // Only apply Levenshtein distance for similar-length words
            let lengthDifference = abs(word.count - query.count)
            if lengthDifference <= 2 {
                let distance = levenshteinDistance(query, word)

                // Allow 1 edit for short words (3-5 chars), 2 edits for longer words
                let maxAllowedDistance = query.count <= 5 ? 1 : 2

                if distance <= maxAllowedDistance {
                    return true
                }
            }
        }

        return false
    }

    /// Calculates Levenshtein Distance between two strings
    /// - Returns: Number of character edits needed to transform one string into another
    private static func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Length = s1Array.count
        let s2Length = s2Array.count

        // Create a matrix to store distances
        var matrix = Array(repeating: Array(repeating: 0, count: s2Length + 1), count: s1Length + 1)

        // Initialize first row and column
        for i in 0...s1Length {
            matrix[i][0] = i
        }
        for j in 0...s2Length {
            matrix[0][j] = j
        }

        // Fill the matrix
        for i in 1...s1Length {
            for j in 1...s2Length {
                let cost = s1Array[i - 1] == s2Array[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,      // Deletion
                    matrix[i][j - 1] + 1,      // Insertion
                    matrix[i - 1][j - 1] + cost // Substitution
                )
                if i > 1 && j > 1 && s1Array[i - 1] == s2Array[j - 2] && s1Array[i - 2] == s2Array[j - 1] {
                    matrix[i][j] = min(matrix[i][j], matrix[i - 2][j - 2] + 1)
                }
            }
        }

        return matrix[s1Length][s2Length]
    }
}
