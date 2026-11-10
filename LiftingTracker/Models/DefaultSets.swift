import Foundation

/// The reps and weight to pre-fill one set with.
struct SetValues: Equatable {
    var reps: Int
    var weight: Double?
}

/// A logged set, reduced to what the defaulting rule needs.
struct LoggedSetSnapshot {
    var plannedExerciseID: UUID?
    var setNumber: Int
    var reps: Int
    var weight: Double?
}

/// A finished session of one workout, reduced to what the defaulting rule needs.
struct SessionSnapshot {
    var finishedAt: Date
    var sets: [LoggedSetSnapshot]
}

struct DefaultSetsResult: Equatable {
    var sets: [SetValues]
    /// When the values were copied from a previous session, the day it finished.
    var sourceDate: Date?
}

/// The core rule of the app: what a session's sets start out as.
///
/// Free of UI and storage code so it can be unit tested directly.
enum DefaultSets {
    static let fallbackSetCount = 3
    static let fallbackReps = 10

    static var fallback: [SetValues] {
        Array(repeating: SetValues(reps: fallbackReps, weight: nil), count: fallbackSetCount)
    }

    /// - Parameters:
    ///   - plannedExerciseID: the workout exercise being pre-filled.
    ///   - history: finished sessions of the same workout, in any order.
    ///     Cancelled and in-progress sessions must not be included.
    /// - Returns: the exact sets from the most recent session that logged this
    ///   exercise, or three sets of 10 reps with no weight.
    static func resolve(plannedExerciseID: UUID, history: [SessionSnapshot]) -> DefaultSetsResult {
        let newestFirst = history.sorted { $0.finishedAt > $1.finishedAt }
        for session in newestFirst {
            let logged = session.sets
                .filter { $0.plannedExerciseID == plannedExerciseID }
                .sorted { $0.setNumber < $1.setNumber }
            if !logged.isEmpty {
                return DefaultSetsResult(
                    sets: logged.map { SetValues(reps: $0.reps, weight: $0.weight) },
                    sourceDate: session.finishedAt
                )
            }
        }
        return DefaultSetsResult(sets: fallback, sourceDate: nil)
    }

    /// The sets to pre-fill for a workout exercise, read from stored history.
    static func defaultSets(for planned: PlannedExercise, in workout: Workout) -> DefaultSetsResult {
        let history: [SessionSnapshot] = workout.sessions.compactMap { session in
            guard let finishedAt = session.finishedAt else { return nil }
            let sets = session.sets
                .filter(\.isDone)
                .map {
                    LoggedSetSnapshot(
                        plannedExerciseID: $0.plannedExerciseID,
                        setNumber: $0.setNumber,
                        reps: $0.reps,
                        weight: $0.weight
                    )
                }
            return SessionSnapshot(finishedAt: finishedAt, sets: sets)
        }
        return resolve(plannedExerciseID: planned.id, history: history)
    }
}
