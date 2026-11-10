import SwiftData
import SwiftUI

/// Shows the session in progress, or the list of workouts to start one from.
struct LiveWorkoutPage: View {
    @Query(filter: #Predicate<WorkoutSession> { $0.finishedAt == nil })
    private var activeSessions: [WorkoutSession]

    @Environment(\.modelContext) private var context
    @State private var endingID: UUID?

    let openWorkouts: () -> Void

    private var current: WorkoutSession? {
        activeSessions.first { $0.id != endingID }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let session = current {
                    ActiveSessionView(session: session) { how in
                        end(session, how)
                    }
                } else {
                    StartSessionView(openWorkouts: openWorkouts)
                }
            }
            .background(Theme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    /// Takes the session off screen first, then finishes or discards it, so the
    /// logging view never draws records that were just removed.
    private func end(_ session: WorkoutSession, _ how: SessionEnd) {
        endingID = session.id
        DispatchQueue.main.async {
            switch how {
            case .finish:
                SessionActions.finish(session, in: context)
            case .cancel:
                SessionActions.cancel(session, in: context)
            }
        }
    }
}

/// With no session in progress: pick a workout, then Start.
private struct StartSessionView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Workout.createdAt) private var workouts: [Workout]
    @State private var selectedID: UUID?

    let openWorkouts: () -> Void

    private var selected: Workout? {
        workouts.first { $0.id == selectedID && !$0.planned.isEmpty }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    PageHeader(
                        title: "Live Workout",
                        subtitle: workouts.isEmpty ? nil : "Pick a workout, then start"
                    )

                    if workouts.isEmpty {
                        VStack(spacing: 4) {
                            EmptyPrompt(
                                title: "No workouts yet",
                                message: "Define a workout first, then come back here to log it."
                            )
                            OutlineButton(title: "Go to Workouts", systemImage: nil, action: openWorkouts)
                        }
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(workouts.enumerated()), id: \.element.id) { index, workout in
                                row(workout)
                                if index < workouts.count - 1 {
                                    Rectangle().fill(Theme.divider).frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .background(
                            Theme.card,
                            in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        )
                    }
                }
                .padding(Theme.pageMargin)
            }

            if !workouts.isEmpty {
                PrimaryButton(title: "Start") {
                    if let selected {
                        SessionActions.start(selected, in: context)
                        selectedID = nil
                    }
                }
                .disabled(selected == nil)
                .accessibilityIdentifier("start-session")
                .padding(.horizontal, Theme.pageMargin)
                .padding(.vertical, 12)
            }
        }
    }

    private func row(_ workout: Workout) -> some View {
        let isEmpty = workout.planned.isEmpty
        let isSelected = workout.id == selectedID && !isEmpty
        return Button {
            selectedID = isSelected ? nil : workout.id
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(workout.name)
                        .font(AppFont.display(24))
                        .foregroundStyle(isEmpty ? Theme.muted : Theme.ink)
                        .multilineTextAlignment(.leading)
                    Text(subtitle(workout))
                        .font(AppFont.text(13))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(isSelected ? Theme.link : Theme.border)
                    .opacity(isEmpty ? 0 : 1)
            }
            .frame(minHeight: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isEmpty)
        .accessibilityIdentifier("start-workout-\(workout.name)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func subtitle(_ workout: Workout) -> String {
        let count = workout.planned.count
        if count == 0 { return "No exercises yet. Add some on the Workouts page." }
        let exercises = count == 1 ? "1 exercise" : "\(count) exercises"
        if let last = workout.lastFinishedAt {
            return "\(exercises) · Last done \(DateFormat.short(last))"
        }
        return "\(exercises) · Not done yet"
    }
}
