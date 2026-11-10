import SwiftData
import SwiftUI

/// Every defined workout, as cards that expand to show the plan.
struct WorkoutsPage: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.createdAt) private var workouts: [Workout]
    @AppStorage(WeightFormat.unitKey) private var unit = WeightFormat.defaultUnit

    @State private var path: [Workout] = []
    @State private var expanded: Set<UUID> = []
    @State private var addingTo: Workout?
    @State private var pendingDelete: Workout?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                PageHeader(title: "Workouts") {
                    CircleIconButton(systemName: "plus", label: "New workout") { createWorkout() }
                }
                .pageRow(top: 16, bottom: 8)

                if workouts.isEmpty {
                    EmptyPrompt(
                        title: "Create your first workout",
                        message: "A workout is a list of exercises with planned sets, reps and weight."
                    )
                    .pageRow()
                }

                ForEach(workouts) { workout in
                    WorkoutCard(
                        workout: workout,
                        unit: unit,
                        isExpanded: expanded.contains(workout.id),
                        toggle: { toggle(workout) },
                        edit: { path.append(workout) },
                        addExercise: { addingTo = workout }
                    )
                    .pageRow()
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete") { pendingDelete = workout }
                            .tint(.red)
                    }
                }

                unitRow
                    .pageRow(top: 16, bottom: 24)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Workout.self) { workout in
                WorkoutEditor(workout: workout)
            }
            .sheet(item: $addingTo) { workout in
                ExercisePicker { exercise in
                    WorkoutActions.add(exercise, to: workout, in: context)
                    expanded.insert(workout.id)
                }
            }
            .confirmationDialog(
                "Delete “\(pendingDelete?.name ?? "")”?",
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { workout in
                Button("Delete workout", role: .destructive) {
                    expanded.remove(workout.id)
                    context.delete(workout)
                    try? context.save()
                }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("Sessions you already logged are kept.")
            }
        }
    }

    private var unitRow: some View {
        HStack {
            Text("Weight unit")
                .font(AppFont.text(13))
                .foregroundStyle(Theme.muted)
            Spacer()
            Picker("Weight unit", selection: $unit) {
                Text("lb").tag("lb")
                Text("kg").tag("kg")
            }
            .pickerStyle(.segmented)
            .frame(width: 120)
        }
    }

    private func toggle(_ workout: Workout) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expanded.contains(workout.id) {
                expanded.remove(workout.id)
            } else {
                expanded.insert(workout.id)
            }
        }
    }

    private func createWorkout() {
        let workout = Workout(name: "New Workout")
        context.insert(workout)
        try? context.save()
        path.append(workout)
    }
}

private extension View {
    /// A list row with no chrome, inset to the page margins.
    func pageRow(top: CGFloat = 6, bottom: CGFloat = 6) -> some View {
        self
            .listRowInsets(EdgeInsets(top: top, leading: Theme.pageMargin, bottom: bottom, trailing: Theme.pageMargin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
    }
}

/// One workout: name, summary line, and when expanded the planned exercises.
private struct WorkoutCard: View {
    let workout: Workout
    let unit: String
    let isExpanded: Bool
    let toggle: () -> Void
    let edit: () -> Void
    let addExercise: () -> Void

    private var subtitle: String {
        let count = workout.planned.count
        let exercises = count == 1 ? "1 exercise" : "\(count) exercises"
        if let last = workout.lastFinishedAt {
            return "\(exercises) · Last done \(DateFormat.short(last))"
        }
        return "\(exercises) · Not done yet"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Button(action: edit) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.name)
                            .font(AppFont.display(24))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.leading)
                        Text(subtitle)
                            .font(AppFont.text(13))
                            .foregroundStyle(Theme.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityHint("Edits this workout")

                ChevronButton(isExpanded: isExpanded, name: workout.name, action: toggle)
            }

            if isExpanded {
                let items = workout.orderedPlanned
                if !items.isEmpty {
                    VStack(spacing: 0) {
                        HStack(spacing: 8) {
                            FieldLabel("Exercise")
                                .frame(maxWidth: .infinity, alignment: .leading)
                            FieldLabel("Sets × reps")
                                .frame(width: 84, alignment: .trailing)
                            FieldLabel("Weight")
                                .frame(width: 68, alignment: .trailing)
                        }
                        .padding(.bottom, 6)
                        divider

                        ForEach(items) { planned in
                            HStack(spacing: 8) {
                                Text(planned.exercise?.name ?? "")
                                    .font(AppFont.text(15))
                                    .foregroundStyle(Theme.ink)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("\(planned.plannedSets) × \(planned.plannedReps)")
                                    .font(AppFont.display(20))
                                    .foregroundStyle(Theme.ink)
                                    .frame(width: 84, alignment: .trailing)
                                Text(WeightFormat.labelled(planned.plannedWeight, unit: unit) ?? "—")
                                    .font(AppFont.display(20))
                                    .foregroundStyle(planned.plannedWeight == nil ? Theme.muted : Theme.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                    .frame(width: 68, alignment: .trailing)
                                    .accessibilityLabel(
                                        WeightFormat.labelled(planned.plannedWeight, unit: unit) ?? "No planned weight"
                                    )
                            }
                            .frame(minHeight: 44)
                            divider
                        }
                    }
                }

                OutlineButton(title: "Add exercise", action: addExercise)
            }
        }
        .card(padding: isExpanded ? 16 : 12)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(workout.name)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
    }
}
