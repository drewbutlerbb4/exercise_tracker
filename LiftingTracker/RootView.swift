import SwiftData
import SwiftUI

enum Page: String, CaseIterable, Identifiable {
    case workouts
    case exercises
    case live

    var id: String { rawValue }

    var title: String {
        switch self {
        case .workouts: return "Workouts"
        case .exercises: return "Exercises"
        case .live: return "Live Workout"
        }
    }
}

/// The navigation bar pinned to the top, above three pages that each keep
/// their own navigation stack and scroll position.
struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<WorkoutSession> { $0.finishedAt == nil })
    private var activeSessions: [WorkoutSession]

    @State private var page: Page = .workouts
    @State private var pickedInitialPage = false

    var body: some View {
        VStack(spacing: 0) {
            TopNavBar(page: $page, sessionInProgress: !activeSessions.isEmpty)
                .padding(.horizontal, Theme.pageMargin)
                .padding(.top, 8)
                .padding(.bottom, 4)

            ZStack {
                keepAlive(.workouts) { WorkoutsPage() }
                keepAlive(.exercises) { ExercisesPage() }
                keepAlive(.live) { LiveWorkoutPage(openWorkouts: { page = .workouts }) }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .tint(Theme.link)
        .onAppear {
            // Open on Workouts, or on Live Workout when a session is in progress.
            guard !pickedInitialPage else { return }
            pickedInitialPage = true
            if SessionActions.activeSession(in: context) != nil {
                page = .live
            }
        }
        .onChange(of: page) {
            hideKeyboard()
        }
    }

    /// Pages stay mounted while hidden so they keep their state.
    private func keepAlive<Content: View>(_ target: Page, @ViewBuilder content: () -> Content) -> some View {
        let isShown = page == target
        return content()
            .opacity(isShown ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
    }
}

/// Segmented control with the three pages.
struct TopNavBar: View {
    @Binding var page: Page
    let sessionInProgress: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Page.allCases) { item in
                let isSelected = item == page
                Button {
                    page = item
                } label: {
                    HStack(spacing: 6) {
                        if item == .live, sessionInProgress {
                            Circle()
                                .fill(isSelected ? Theme.ink : Theme.link)
                                .frame(width: 6, height: 6)
                                .accessibilityHidden(true)
                        }
                        Text(item.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isSelected ? Theme.accent : Color.clear)
                    )
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("nav-\(item.rawValue)")
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                .accessibilityValue(item == .live && sessionInProgress ? "Session in progress" : "")
            }
        }
        .frame(height: 44)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
    }
}
