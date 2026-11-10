import SwiftData
import SwiftUI

/// The exercise library: alphabetical, searchable, each row expanding in place
/// to edit its description and notes.
struct ExercisesPage: View {
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]

    @State private var path: [Exercise] = []
    @State private var search = ""
    @State private var expanded: Set<UUID> = []
    @State private var showingNew = false
    @State private var newName = ""
    @State private var nameError: String?

    private var visible: [Exercise] {
        let sorted = exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// Expanded exercises stand alone as cards; runs of collapsed ones share a card.
    private var segments: [Segment] {
        var result: [Segment] = []
        var run: [Exercise] = []
        for exercise in visible {
            if expanded.contains(exercise.id) {
                if !run.isEmpty {
                    result.append(.collapsed(run))
                    run = []
                }
                result.append(.expanded(exercise))
            } else {
                run.append(exercise)
            }
        }
        if !run.isEmpty { result.append(.collapsed(run)) }
        return result
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader(title: "Exercises") {
                        CircleIconButton(systemName: "plus", label: "New exercise") {
                            newName = ""
                            showingNew = true
                        }
                    }

                    searchField

                    if exercises.isEmpty {
                        EmptyPrompt(
                            title: "Create your first exercise",
                            message: "Exercises you add here can be used in any workout."
                        )
                    } else if visible.isEmpty {
                        EmptyPrompt(title: "No matches", message: "No exercise is named “\(search)”.")
                    } else {
                        VStack(spacing: 12) {
                            ForEach(segments) { segment in
                                switch segment {
                                case .expanded(let exercise):
                                    ExpandedExerciseCard(
                                        exercise: exercise,
                                        collapse: { toggle(exercise) },
                                        openDetail: { path.append(exercise) }
                                    )
                                case .collapsed(let run):
                                    collapsedCard(run)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.pageMargin)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Exercise.self) { exercise in
                ExerciseDetail(exercise: exercise)
            }
            .alert("New exercise", isPresented: $showingNew) {
                TextField("Name", text: $newName)
                    .textInputAutocapitalization(.words)
                Button("Create") { create() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Up to \(ExerciseActions.nameLimit) characters.")
            }
            .alert(
                "Can’t create exercise",
                isPresented: Binding(get: { nameError != nil }, set: { if !$0 { nameError = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(nameError ?? "")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            TextField("Search exercises", text: $search)
                .font(AppFont.text(15))
                .foregroundStyle(Theme.ink)
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                        .frame(width: 32, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }

    private func collapsedCard(_ run: [Exercise]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(run.enumerated()), id: \.element.id) { index, exercise in
                CollapsedExerciseRow(exercise: exercise) { toggle(exercise) }
                if index < run.count - 1 {
                    Rectangle()
                        .fill(Theme.divider)
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private func toggle(_ exercise: Exercise) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expanded.contains(exercise.id) {
                expanded.remove(exercise.id)
            } else {
                expanded.insert(exercise.id)
            }
        }
        hideKeyboard()
    }

    private func create() {
        let name = ExerciseActions.normalized(newName)
        guard !name.isEmpty else { return }
        guard let exercise = ExerciseActions.create(name: name, existing: exercises, in: context) else {
            nameError = "An exercise named “\(name)” already exists."
            return
        }
        search = ""
        expanded.insert(exercise.id)
    }
}

private enum Segment: Identifiable {
    case expanded(Exercise)
    case collapsed([Exercise])

    var id: String {
        switch self {
        case .expanded(let exercise):
            return "expanded-\(exercise.id.uuidString)"
        case .collapsed(let run):
            return "collapsed-\(run.first?.id.uuidString ?? "")"
        }
    }
}

/// Name and the first line of the description.
private struct CollapsedExerciseRow: View {
    let exercise: Exercise
    let expand: () -> Void

    var body: some View {
        Button(action: expand) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(AppFont.text(16, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.leading)
                    if !exercise.summary.isEmpty {
                        Text(exercise.summary)
                            .font(AppFont.text(13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 44, height: 44)
            }
            .frame(minHeight: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Expand \(exercise.name)")
    }
}

/// Description and notes, edited in place. Changes save as you type.
private struct ExpandedExerciseCard: View {
    @Environment(\.modelContext) private var context
    @Bindable var exercise: Exercise
    let collapse: () -> Void
    let openDetail: () -> Void

    private var usedIn: String {
        let names = ExerciseActions.workoutNames(using: exercise)
        guard !names.isEmpty else { return "Not used in a workout yet" }
        return "Used in " + ListFormatter.localizedString(byJoining: names)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(exercise.name)
                    .font(AppFont.display(24))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                ChevronButton(isExpanded: true, name: exercise.name, action: collapse)
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Description")
                TextEditor(text: $exercise.summary)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(height: 72)
                    .modifier(TextBoxStyle())
                    .accessibilityLabel("Description")
                    .onChange(of: exercise.summary) { _, new in
                        if new.count > ExerciseActions.summaryLimit {
                            exercise.summary = String(new.prefix(ExerciseActions.summaryLimit))
                        }
                        try? context.save()
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                FieldLabel("Notes")
                TextEditor(text: $exercise.notes)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(height: 94)
                    .modifier(TextBoxStyle())
                    .accessibilityLabel("Notes")
                    .onChange(of: exercise.notes) { _, new in
                        if new.count > ExerciseActions.notesLimit {
                            exercise.notes = String(new.prefix(ExerciseActions.notesLimit))
                        }
                        try? context.save()
                    }
            }

            Text(usedIn)
                .font(AppFont.text(13))
                .foregroundStyle(Theme.muted)

            Button(action: openDetail) {
                HStack(spacing: 4) {
                    Text("Rename, history and delete")
                        .font(AppFont.text(15, weight: .semibold))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(Theme.link)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .card()
    }
}
