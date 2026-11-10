import SwiftData
import SwiftUI

/// Logging a session: one card per exercise, one row per set, every field
/// pre-filled. Every edit is saved straight away.
struct ActiveSessionView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(WeightFormat.unitKey) private var unit = WeightFormat.defaultUnit

    let session: WorkoutSession
    /// Ends the session. The page swaps this view out before the data changes.
    let end: (SessionEnd) -> Void
    @State private var confirmingCancel = false
    @State private var confirmingEmptyFinish = false

    private var groups: [ExerciseGroup] {
        Dictionary(grouping: session.sets.filter { !$0.isDeleted }, by: \.position)
            .map { ExerciseGroup(position: $0.key, sets: $0.value.sorted { $0.setNumber < $1.setNumber }) }
            .sorted { $0.position < $1.position }
    }

    var body: some View {
        let groups = self.groups
        List {
            PageHeader(
                title: session.workout?.name ?? session.workoutName,
                subtitle: "In progress · \(groups.count == 1 ? "1 exercise" : "\(groups.count) exercises")"
            )
            .listRowInsets(EdgeInsets(top: 16, leading: Theme.pageMargin, bottom: 10, trailing: Theme.pageMargin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            ForEach(groups) { group in
                exerciseHeader(group)
                    .cardRow(.top)

                ForEach(group.sets) { set in
                    SetRow(set: set, exerciseName: group.name, position: group.position) {
                        try? context.save()
                    }
                    .cardRow(.middle)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if group.sets.count > 1 {
                            Button("Remove") {
                                SessionActions.removeSet(set, from: session, context: context)
                            }
                            .tint(.red)
                        }
                    }
                }

                OutlineButton(title: "Add set") {
                    if let last = group.sets.last {
                        SessionActions.addSet(after: last, in: session, context: context)
                    }
                }
                .accessibilityLabel("Add set to \(group.name)")
                .cardRow(.bottom)

                Color.clear
                    .frame(height: 12)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                    .accessibilityHidden(true)
            }

            VStack(spacing: 4) {
                PrimaryButton(title: "Finish workout") { finish() }
                    .accessibilityIdentifier("finish-workout")
                Button {
                    confirmingCancel = true
                } label: {
                    Text("Cancel workout")
                        .font(AppFont.text(15, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: Theme.pageMargin, bottom: 16, trailing: Theme.pageMargin))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 1)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .modifier(KeyboardDoneToolbar())
        .confirmationDialog("Cancel this workout?", isPresented: $confirmingCancel, titleVisibility: .visible) {
            Button("Discard session", role: .destructive) {
                end(.cancel)
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Everything logged in this session will be discarded.")
        }
        .confirmationDialog("No sets are checked", isPresented: $confirmingEmptyFinish, titleVisibility: .visible) {
            Button("Discard session", role: .destructive) {
                end(.cancel)
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Only checked sets are saved. Discard this session instead?")
        }
    }

    private func finish() {
        hideKeyboard()
        if session.sets.contains(where: \.isDone) {
            end(.finish)
        } else {
            confirmingEmptyFinish = true
        }
    }

    private func exerciseHeader(_ group: ExerciseGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(AppFont.display(24))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                if let notes = group.notes {
                    Text(notes)
                        .font(AppFont.text(13))
                        .foregroundStyle(Theme.muted)
                }
                Text(referenceLine(group))
                    .font(AppFont.text(13))
                    .foregroundStyle(Theme.muted)
            }

            HStack(spacing: 8) {
                FieldLabel("Set")
                    .frame(width: SetRow.numberWidth, alignment: .leading)
                FieldLabel("Reps")
                    .frame(maxWidth: .infinity, alignment: .leading)
                FieldLabel("Weight (\(unit))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                FieldLabel("Done")
                    .frame(width: SetRow.checkWidth, alignment: .center)
            }
        }
    }

    /// "Plan: 3 × 10 at 135 lb · Filled from Nov 6"
    private func referenceLine(_ group: ExerciseGroup) -> String {
        let fallback = "\(DefaultSets.fallbackSetCount) × \(DefaultSets.fallbackReps)"
        guard
            let workout = session.workout,
            let plannedID = group.plannedExerciseID,
            let planned = workout.planned.first(where: { $0.id == plannedID })
        else {
            return "No previous session · Starting at \(fallback)"
        }

        var plan = "Plan: \(planned.plannedSets) × \(planned.plannedReps)"
        if let weight = WeightFormat.labelled(planned.plannedWeight, unit: unit) {
            plan += " at \(weight)"
        }
        if let source = DefaultSets.defaultSets(for: planned, in: workout).sourceDate {
            return "\(plan) · Filled from \(DateFormat.short(source))"
        }
        return "\(plan) · No previous session, starting at \(fallback)"
    }
}

enum SessionEnd {
    case finish
    case cancel
}

/// The sets logged for one exercise position in the session.
private struct ExerciseGroup: Identifiable {
    let position: Int
    let sets: [LoggedSet]

    var id: Int { position }

    var name: String {
        sets.first?.exercise?.name ?? sets.first?.exerciseName ?? ""
    }

    var notes: String? {
        guard let notes = sets.first?.exercise?.notes, !notes.isEmpty else { return nil }
        return notes
    }

    var plannedExerciseID: UUID? {
        sets.first?.plannedExerciseID
    }
}

/// Set number, reps, weight and the Done check.
private struct SetRow: View {
    static let numberWidth: CGFloat = 28
    static let checkWidth: CGFloat = 44

    @Bindable var set: LoggedSet
    let exerciseName: String
    let position: Int
    let save: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("\(set.setNumber)")
                .font(AppFont.display(22))
                .foregroundStyle(Theme.muted)
                .frame(width: Self.numberWidth, alignment: .leading)
                .accessibilityLabel("Set \(set.setNumber)")

            RepsField(value: $set.reps, label: "\(exerciseName) set \(set.setNumber) reps")
                .frame(maxWidth: .infinity)

            WeightField(value: $set.weight, label: "\(exerciseName) set \(set.setNumber) weight")
                .frame(maxWidth: .infinity)

            Button {
                set.isDone.toggle()
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(set.isDone ? Theme.link : Theme.border)
                    .frame(width: Self.checkWidth, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(exerciseName) set \(set.setNumber) done")
            .accessibilityValue(set.isDone ? "Checked" : "Not checked")
            .accessibilityIdentifier("done-\(position)-\(set.setNumber)")
        }
        .onChange(of: set.reps) { save() }
        .onChange(of: set.weight) { save() }
        .onChange(of: set.isDone) { save() }
    }
}

private enum CardRowPart {
    case top
    case middle
    case bottom
}

private extension View {
    /// Draws consecutive list rows as one rounded card, so set rows keep
    /// swipe-to-remove.
    func cardRow(_ part: CardRowPart) -> some View {
        let radius = Theme.cardRadius
        let inset = Theme.pageMargin + 16
        return self
            .listRowInsets(
                EdgeInsets(
                    top: part == .top ? 16 : 4,
                    leading: inset,
                    bottom: part == .bottom ? 16 : 4,
                    trailing: inset
                )
            )
            .listRowSeparator(.hidden)
            .listRowBackground(
                UnevenRoundedRectangle(
                    topLeadingRadius: part == .top ? radius : 0,
                    bottomLeadingRadius: part == .bottom ? radius : 0,
                    bottomTrailingRadius: part == .bottom ? radius : 0,
                    topTrailingRadius: part == .top ? radius : 0,
                    style: .continuous
                )
                .fill(Theme.card)
                .padding(.horizontal, Theme.pageMargin)
            )
    }
}
