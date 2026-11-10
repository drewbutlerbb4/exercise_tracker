import Foundation
import SwiftData
import SwiftUI

/// Starting, finishing and cancelling live sessions.
enum SessionActions {
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.finishedAt == nil }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Starts a session pre-filled from the last one. Returns nil when a session
    /// is already in progress: only one can run at a time.
    @discardableResult
    static func start(_ workout: Workout, in context: ModelContext) -> WorkoutSession? {
        guard activeSession(in: context) == nil else { return nil }

        // Read defaults before the new session exists.
        let plan = workout.orderedPlanned.map { planned in
            (planned: planned, defaults: DefaultSets.defaultSets(for: planned, in: workout))
        }

        let session = WorkoutSession(workoutName: workout.name)
        context.insert(session)
        session.workout = workout

        for (index, entry) in plan.enumerated() {
            for (setIndex, values) in entry.defaults.sets.enumerated() {
                let set = LoggedSet(
                    exerciseName: entry.planned.exercise?.name ?? "",
                    plannedExerciseID: entry.planned.id,
                    position: index,
                    setNumber: setIndex + 1,
                    reps: values.reps,
                    weight: values.weight
                )
                context.insert(set)
                set.session = session
                set.exercise = entry.planned.exercise
            }
        }
        try? context.save()
        return session
    }

    /// Adds a set to one exercise of the session, copying the last set's values.
    static func addSet(after last: LoggedSet, in session: WorkoutSession, context: ModelContext) {
        let set = LoggedSet(
            exerciseName: last.exerciseName,
            plannedExerciseID: last.plannedExerciseID,
            position: last.position,
            setNumber: last.setNumber + 1,
            reps: last.reps,
            weight: last.weight
        )
        context.insert(set)
        set.session = session
        set.exercise = last.exercise
        try? context.save()
    }

    static func removeSet(_ set: LoggedSet, from session: WorkoutSession, context: ModelContext) {
        let position = set.position
        let removedID = set.id
        context.delete(set)
        renumber(session.sets.filter { $0.position == position && $0.id != removedID })
        try? context.save()
    }

    /// Saves the session to history. Unchecked sets are dropped, so they are not
    /// used as defaults next time.
    static func finish(_ session: WorkoutSession, in context: ModelContext) {
        let unchecked = session.sets.filter { !$0.isDone }
        let kept = session.sets.filter(\.isDone)
        for set in unchecked {
            context.delete(set)
        }
        for sets in Dictionary(grouping: kept, by: \.position).values {
            renumber(sets)
        }
        // Keep the names current as of the day it was performed.
        for set in kept {
            if let name = set.exercise?.name { set.exerciseName = name }
        }
        if let name = session.workout?.name { session.workoutName = name }
        session.finishedAt = Date()
        try? context.save()
    }

    static func cancel(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    private static func renumber(_ sets: [LoggedSet]) {
        for (index, set) in sets.sorted(by: { $0.setNumber < $1.setNumber }).enumerated() {
            set.setNumber = index + 1
        }
    }
}

/// Editing workout plans.
enum WorkoutActions {
    static func add(_ exercise: Exercise, to workout: Workout, in context: ModelContext) {
        let next = (workout.planned.map(\.position).max() ?? -1) + 1
        let planned = PlannedExercise(position: next)
        context.insert(planned)
        planned.workout = workout
        planned.exercise = exercise
        try? context.save()
    }

    static func move(in workout: Workout, from source: IndexSet, to destination: Int, context: ModelContext) {
        var items = workout.orderedPlanned
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() {
            item.position = index
        }
        try? context.save()
    }

    static func remove(at offsets: IndexSet, from workout: Workout, context: ModelContext) {
        let items = workout.orderedPlanned
        for index in offsets {
            context.delete(items[index])
        }
        try? context.save()
    }
}

/// Creating and naming exercises. Names are required, unique and up to 40 characters.
enum ExerciseActions {
    static let nameLimit = 40
    static let summaryLimit = 200
    static let notesLimit = 500

    static func normalized(_ name: String) -> String {
        String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(nameLimit))
    }

    static func isTaken(_ name: String, in exercises: [Exercise], excluding: Exercise? = nil) -> Bool {
        let wanted = normalized(name)
        return exercises.contains { other in
            other.id != excluding?.id
                && other.name.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
    }

    /// Returns nil when the name is empty or already used.
    static func create(name: String, existing: [Exercise], in context: ModelContext) -> Exercise? {
        let clean = normalized(name)
        guard !clean.isEmpty, !isTaken(clean, in: existing) else { return nil }
        let exercise = Exercise(name: clean)
        context.insert(exercise)
        try? context.save()
        return exercise
    }

    /// Names of the workouts that use this exercise, each listed once.
    static func workoutNames(using exercise: Exercise) -> [String] {
        var seen = Set<UUID>()
        var names: [String] = []
        for planned in exercise.planned {
            guard let workout = planned.workout, seen.insert(workout.id).inserted else { continue }
            names.append(workout.name)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

/// Data for the UI test, so it can start a session without building one by hand.
enum SampleData {
    static func seed(_ context: ModelContext) {
        let bench = Exercise(
            name: "Barbell Bench Press",
            summary: "Flat bench. Lower the bar to mid-chest, then press to lockout.",
            notes: "Ring fingers on the knurl marks. Feet flat."
        )
        context.insert(bench)
        let workout = Workout(name: "Push Day")
        context.insert(workout)
        let planned = PlannedExercise(position: 0, plannedSets: 3, plannedReps: 10, plannedWeight: 135)
        context.insert(planned)
        planned.workout = workout
        planned.exercise = bench
        try? context.save()
    }
}
