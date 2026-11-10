import Charts
import SwiftData
import SwiftUI

/// The pushed exercise screen: rename, progress over time, delete.
struct ExerciseDetail: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allExercises: [Exercise]
    @AppStorage(WeightFormat.unitKey) private var unit = WeightFormat.defaultUnit

    @Bindable var exercise: Exercise
    @State private var name = ""
    @State private var nameProblem: String?
    @State private var confirmingDelete = false

    private var history: [HistoryEntry] {
        let finished = exercise.loggedSets.filter { $0.isDone && $0.session?.finishedAt != nil }
        let bySession = Dictionary(grouping: finished) { $0.session?.id ?? UUID() }
        let entries: [HistoryEntry] = bySession.compactMap { entry in
            guard let session = entry.value.first?.session, let date = session.finishedAt else { return nil }
            let sets = entry.value.sorted {
                ($0.position, $0.setNumber) < ($1.position, $1.setNumber)
            }
            return HistoryEntry(id: entry.key, date: date, workoutName: session.workoutName, sets: sets)
        }
        return entries.sorted { $0.date > $1.date }
    }

    var body: some View {
        let entries = history
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BackButton(title: "Exercises")

                VStack(alignment: .leading, spacing: 6) {
                    FieldLabel("Name")
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .modifier(TextBoxStyle())
                        .onChange(of: name) { _, new in commitName(new) }
                    if let nameProblem {
                        Text(nameProblem)
                            .font(AppFont.text(13))
                            .foregroundStyle(Theme.danger)
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: 12) {
                    Text("History")
                        .font(AppFont.display(24))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)

                    if entries.isEmpty {
                        Text("No finished sessions yet. Sets you check off in a live workout appear here.")
                            .font(AppFont.text(15))
                            .foregroundStyle(Theme.muted)
                    } else {
                        chart(entries)
                        VStack(spacing: 0) {
                            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                                historyRow(entry)
                                if index < entries.count - 1 {
                                    Rectangle().fill(Theme.divider).frame(height: 1)
                                }
                            }
                        }
                    }
                }
                .card()

                Button {
                    confirmingDelete = true
                } label: {
                    Text("Delete exercise")
                        .font(AppFont.text(15, weight: .semibold))
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Theme.pageMargin)
            .padding(.bottom, Theme.pageMargin)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { name = exercise.name }
        .confirmationDialog(
            "Delete “\(exercise.name)”?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete exercise", role: .destructive) { delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteMessage)
        }
    }

    private var deleteMessage: String {
        let names = ExerciseActions.workoutNames(using: exercise)
        if names.isEmpty {
            return "Logged history is kept."
        }
        return "It will be removed from \(ListFormatter.localizedString(byJoining: names)). Logged history is kept."
    }

    @ViewBuilder
    private func chart(_ entries: [HistoryEntry]) -> some View {
        let points = entries.compactMap { entry -> ChartPoint? in
            guard let heaviest = entry.heaviest else { return nil }
            return ChartPoint(id: entry.id, date: entry.date, weight: heaviest)
        }
        if points.isEmpty {
            Text("No weights logged yet, so there is nothing to chart.")
                .font(AppFont.text(13))
                .foregroundStyle(Theme.muted)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Heaviest set per session (\(unit))")
                Chart(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                    .interpolationMethod(.linear)
                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Weight", point.weight)
                    )
                }
                .foregroundStyle(Theme.link)
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 180)
                .accessibilityLabel("Heaviest weight lifted per session")
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(DateFormat.long(entry.date))
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(entry.workoutName)
                    .font(AppFont.text(13))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            Text(entry.summary(unit: unit))
                .font(AppFont.text(13))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.vertical, 4)
    }

    /// Saves the name as you type when it is valid; otherwise says why not and
    /// keeps the last good name.
    private func commitName(_ text: String) {
        if text.count > ExerciseActions.nameLimit {
            name = String(text.prefix(ExerciseActions.nameLimit))
            return
        }
        let clean = ExerciseActions.normalized(text)
        if clean.isEmpty {
            nameProblem = "A name is required. Still saved as “\(exercise.name)”."
        } else if ExerciseActions.isTaken(clean, in: allExercises, excluding: exercise) {
            nameProblem = "Another exercise already uses that name. Still saved as “\(exercise.name)”."
        } else {
            nameProblem = nil
            if exercise.name != clean {
                exercise.name = clean
                try? context.save()
            }
        }
    }

    private func delete() {
        let doomed = exercise
        dismiss()
        // Delete once this screen has gone, so it never draws a deleted record.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            context.delete(doomed)
            try? context.save()
        }
    }
}

private struct ChartPoint: Identifiable {
    let id: UUID
    let date: Date
    let weight: Double
}

private struct HistoryEntry: Identifiable {
    let id: UUID
    let date: Date
    let workoutName: String
    let sets: [LoggedSet]

    var heaviest: Double? {
        sets.compactMap(\.weight).max()
    }

    /// "10 × 135 · 9 × 135 · 8 × 130 lb", or just reps for bodyweight sets.
    func summary(unit: String) -> String {
        let parts = sets.map { set -> String in
            if set.weight != nil {
                return "\(set.reps) × \(WeightFormat.string(set.weight))"
            }
            return "\(set.reps)"
        }
        let joined = parts.joined(separator: " · ")
        return heaviest == nil ? "\(joined) reps" : "\(joined) \(unit)"
    }
}
