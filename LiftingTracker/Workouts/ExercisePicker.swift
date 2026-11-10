import SwiftData
import SwiftUI

/// The sheet behind "Add exercise": the library with search, plus a shortcut
/// to create a new exercise without leaving the workout.
struct ExercisePicker: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]

    let onPick: (Exercise) -> Void
    @State private var search = ""

    private var query: String {
        ExerciseActions.normalized(search)
    }

    private var matches: [Exercise] {
        let sorted = exercises.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    private var canCreate: Bool {
        !query.isEmpty && !ExerciseActions.isTaken(query, in: exercises)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add exercise")
                    .font(AppFont.display(30, bold: true, relativeTo: .title))
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(AppFont.text(15, weight: .semibold))
                    .foregroundStyle(Theme.link)
                    .frame(minHeight: 44)
            }

            TextField("Search or type a new name", text: $search)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .modifier(TextBoxStyle())
                .onChange(of: search) { _, new in
                    if new.count > ExerciseActions.nameLimit {
                        search = String(new.prefix(ExerciseActions.nameLimit))
                    }
                }

            ScrollView {
                VStack(spacing: 12) {
                    if canCreate {
                        OutlineButton(title: "Create “\(query)”") {
                            if let exercise = ExerciseActions.create(name: query, existing: exercises, in: context) {
                                pick(exercise)
                            }
                        }
                    } else if query.isEmpty {
                        Text("Not in the list? Type its name to create it.")
                            .font(AppFont.text(13))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if !matches.isEmpty {
                        VStack(spacing: 0) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { index, exercise in
                                Button {
                                    pick(exercise)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(AppFont.text(16, weight: .semibold))
                                            .foregroundStyle(Theme.ink)
                                        if !exercise.summary.isEmpty {
                                            Text(exercise.summary)
                                                .font(AppFont.text(13))
                                                .foregroundStyle(Theme.muted)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                if index < matches.count - 1 {
                                    Rectangle().fill(Theme.divider).frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .padding(Theme.pageMargin)
        .background(Theme.background.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func pick(_ exercise: Exercise) {
        onPick(exercise)
        dismiss()
    }
}
