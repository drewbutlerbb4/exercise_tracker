import Foundation
import SwiftData

/// An exercise in the user's library. Defined once, reused in any number of workouts.
@Model
final class Exercise {
    var id: UUID
    var name: String
    /// The short description of the movement ("description" is reserved by Swift).
    var summary: String
    var notes: String
    var createdAt: Date

    /// Removing an exercise removes it from every workout plan...
    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.exercise)
    var planned: [PlannedExercise] = []

    /// ...but logged history is kept (each set also stores the name as text).
    @Relationship(deleteRule: .nullify, inverse: \LoggedSet.exercise)
    var loggedSets: [LoggedSet] = []

    init(name: String, summary: String = "", notes: String = "") {
        self.id = UUID()
        self.name = name
        self.summary = summary
        self.notes = notes
        self.createdAt = Date()
    }
}

/// A named, ordered list of planned exercises.
@Model
final class Workout {
    var id: UUID
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \PlannedExercise.workout)
    var planned: [PlannedExercise] = []

    /// Deleting a workout keeps its sessions.
    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.workout)
    var sessions: [WorkoutSession] = []

    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdAt = Date()
    }

    var orderedPlanned: [PlannedExercise] {
        planned.sorted { $0.position < $1.position }
    }

    var lastFinishedAt: Date? {
        sessions.compactMap(\.finishedAt).max()
    }
}

/// One exercise inside a workout, with its planned sets, reps and weight.
@Model
final class PlannedExercise {
    var id: UUID
    var workout: Workout?
    var exercise: Exercise?
    var position: Int
    var plannedSets: Int
    var plannedReps: Int
    /// No value means "left empty". Never stored as 0 unless the user typed 0.
    var plannedWeight: Double?

    init(position: Int, plannedSets: Int = 3, plannedReps: Int = 10, plannedWeight: Double? = nil) {
        self.id = UUID()
        self.position = position
        self.plannedSets = plannedSets
        self.plannedReps = plannedReps
        self.plannedWeight = plannedWeight
    }
}

/// One performance of a workout. No `finishedAt` means it is in progress.
@Model
final class WorkoutSession {
    var id: UUID
    var workout: Workout?
    /// Stored as text so history stays readable after the workout is deleted.
    var workoutName: String
    var startedAt: Date
    var finishedAt: Date?

    @Relationship(deleteRule: .cascade, inverse: \LoggedSet.session)
    var sets: [LoggedSet] = []

    init(workoutName: String) {
        self.id = UUID()
        self.workoutName = workoutName
        self.startedAt = Date()
        self.finishedAt = nil
    }
}

/// One set recorded in a session.
@Model
final class LoggedSet {
    var id: UUID
    var session: WorkoutSession?
    var exercise: Exercise?
    /// Stored as text so history stays readable after the exercise is deleted.
    var exerciseName: String
    /// The planned exercise this set was logged for. Used to match defaults next
    /// time, so reordering a workout or listing an exercise twice still works.
    var plannedExerciseID: UUID?
    /// Position of the exercise within the session.
    var position: Int
    var setNumber: Int
    var reps: Int
    /// No value means "left empty" (bodyweight). Distinct from 0.
    var weight: Double?
    /// The Done check. Sets left unchecked at Finish are not saved.
    var isDone: Bool

    init(
        exerciseName: String,
        plannedExerciseID: UUID?,
        position: Int,
        setNumber: Int,
        reps: Int,
        weight: Double?,
        isDone: Bool = false
    ) {
        self.id = UUID()
        self.exerciseName = exerciseName
        self.plannedExerciseID = plannedExerciseID
        self.position = position
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.isDone = isDone
    }
}

enum AppSchema {
    static let models: [any PersistentModel.Type] = [
        Exercise.self,
        Workout.self,
        PlannedExercise.self,
        WorkoutSession.self,
        LoggedSet.self,
    ]
}
