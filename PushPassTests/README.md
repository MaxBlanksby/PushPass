Search regression checks use the production SwiftData models and search implementation. Run from the repository root on macOS with Xcode installed:

```sh
swiftc -o /tmp/LiftingLoggerSearchTests LiftingLogger/App/AppConstants.swift LiftingLogger/Models/WorkoutModels.swift LiftingLogger/Services/ExerciseLibrary.swift LiftingLogger/Services/ExerciseSearchEngine.swift PushPassTests/SearchEngineTests.swift PushPassTests/SearchRegressionRunner.swift
cp LiftingLogger/Services/LiftingLogger_Exercise_Library.json /tmp/LiftingLogger_Exercise_Library.json
/tmp/LiftingLoggerSearchTests
```

The runner exits unsuccessfully on failure. It covers abbreviations, synonyms, typos, token order, query filtering, punctuation, and exact-name ranking across the bundled exercise library. These files remain outside the app target.
