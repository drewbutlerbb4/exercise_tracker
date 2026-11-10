import SwiftData
import SwiftUI

/// The pushed workout screen: name, ordered exercises and their planned values.
/// Changes save automatically and never alter past sessions.
struct WorkoutEditor: View {
    @Environment(\.modelContext) private var context
    @AppStorage(WeightFormat.unitKey) private var unit = WeightFormat.defaultUnit

    @Bindable var workout: Workout
    @State private var name = ""
    @State private var showingPicker = false
    @FocusState private var nameFocused: Bool

    private static let nameLimit = 40

    var body: some View {
        let items = workout.orderedPlanned
        List {
            Section {
                BackButton(title: "Workouts")
                    .listRowInsets(EdgeInsets(top: 0, leading: Theme.pageMargin, bottom: 0, trailing: Theme.pageMargin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Name")
                    TextField("Workout name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($nameFocused)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .modifier(TextBoxStyle())
                        .onChange(of: name) { _, new in commitName(new) }
                    if name.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text("A name is required. Still saved as “\(workout.name)”.")
                            .font(AppFont.text(13))
                            .foregroundStyle(Theme.danger)
                    }
                }
                .padding(16)
                .listRowInsets(EdgeInsets(top: 0, leading: Theme.pageMargin, bottom: 12, trailing: Theme.pageMargin))
                .listRowBackground(
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .fill(Theme.card)
                        .padding(.horizontal, Theme.pageMargin)
                        .padding(.bottom, 12)
                )
                .listRowSeparator(.hidden)
            }

            Section {
                ForEach(items) { planned in
                    PlannedExerciseRow(planned: planned, unit: unit)
                        .listRowBackground(Theme.card)
                        .listRowSeparatorTint(Theme.divider)
                }
                .onMove { source, destination in
                    WorkoutActions.move(in: workout, from: source, to: destination, context: context)
                }
                .onDelete { offsets in
                    WorkoutActions.remove(at: offsets, from: workout, context: context)
                }
            } header: {
                FieldLabel("Exercises")
                    .padding(.horizontal, Theme.pageMargin)
            } footer: {
                if items.count > 1 {
                    Text("Hold and drag to reorder. Swipe left to remove.")
                        .font(AppFont.text(13))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.pageMargin)
                } else if items.count == 1 {
                    Text("Swipe left to remove.")
                        .font(AppFont.text(13))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, Theme.pageMargin)
                }
            }

            Section {
                OutlineButton(title: "Add exercise") { showingPicker = true }
                    .listRowInsets(EdgeInsets(top: 8, leading: Theme.pageMargin, bottom: 24, trailing: Theme.pageMargin))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .modifier(KeyboardDoneToolbar())
        .sheet(isPresented: $showingPicker) {
            ExercisePicker { exercise in
                WorkoutActions.add(exercise, to: workout, in: context)
            }
        }
        .onAppear {
            name = workout.name
            // A brand-new workout opens ready to be named.
            if workout.planned.isEmpty, workout.name == "New Workout" {
                nameFocused = true
            }
        }
    }

    private func commitName(_ text: String) {
        if text.count > Self.nameLimit {
            name = String(text.prefix(Self.nameLimit))
            return
        }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !clean.isEmpty, clean != workout.name {
            workout.name = clean
            try? context.save()
        }
    }
}

/// One planned exercise: sets stepper, reps and optional weight.
private struct PlannedExerciseRow: View {
    @Environment(\.modelContext) private var context
    @Bindable var planned: PlannedExercise
    let unit: String

    private var exerciseName: String {
        planned.exercise?.name ?? ""
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(exerciseName)
                .font(AppFont.text(16, weight: .semibold))
                .foregroundStyle(Theme.ink)

            HStack(alignment: .bottom, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel("Sets")
                    HStack(spacing: 8) {
                        Text("\(planned.plannedSets)")
                            .font(AppFont.display(22))
                            .foregroundStyle(Theme.ink)
                            .frame(minWidth: 22, alignment: .leading)
                        Stepper("Sets for \(exerciseName)", value: $planned.plannedSets, in: 1...20)
                            .labelsHidden()
                    }
                    .frame(minHeight: 44)
                }

                Spacer(minLength: 4)

                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel("Reps")
                    RepsField(value: $planned.plannedReps, label: "Reps for \(exerciseName)")
                        .frame(width: 64)
                }

                VStack(alignment: .leading, spacing: 4) {
                    FieldLabel("Weight (\(unit))")
                    WeightField(value: $planned.plannedWeight, label: "Weight for \(exerciseName)")
                        .frame(width: 88)
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: planned.plannedSets) { try? context.save() }
        .onChange(of: planned.plannedReps) { try? context.save() }
        .onChange(of: planned.plannedWeight) { try? context.save() }
    }
}
