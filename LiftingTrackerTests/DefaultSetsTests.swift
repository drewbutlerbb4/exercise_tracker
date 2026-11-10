import XCTest
@testable import LiftingTracker

/// The defaulting rule: what a session's sets are pre-filled with.
final class DefaultSetsTests: XCTestCase {
    private let bench = UUID()
    private let fly = UUID()

    private func day(_ offset: Int) -> Date {
        Date(timeIntervalSince1970: 1_700_000_000 + Double(offset) * 86_400)
    }

    private func set(_ planned: UUID, _ number: Int, _ reps: Int, _ weight: Double?) -> LoggedSetSnapshot {
        LoggedSetSnapshot(plannedExerciseID: planned, setNumber: number, reps: reps, weight: weight)
    }

    func testNoHistoryStartsAtThreeSetsOfTenWithEmptyWeight() {
        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [])

        XCTAssertEqual(result.sets, Array(repeating: SetValues(reps: 10, weight: nil), count: 3))
        XCTAssertNil(result.sourceDate)
    }

    func testCopiesLastSessionSetBySet() {
        let last = SessionSnapshot(finishedAt: day(1), sets: [
            set(bench, 1, 10, 135),
            set(bench, 2, 9, 135),
            set(bench, 3, 8, 130),
        ])

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [last])

        XCTAssertEqual(result.sets, [
            SetValues(reps: 10, weight: 135),
            SetValues(reps: 9, weight: 135),
            SetValues(reps: 8, weight: 130),
        ])
        XCTAssertEqual(result.sourceDate, day(1))
    }

    func testFourSetsLastTimeStartsWithFourSets() {
        let last = SessionSnapshot(finishedAt: day(1), sets: (1...4).map { set(bench, $0, 10, 100) })

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [last])

        XCTAssertEqual(result.sets.count, 4)
    }

    func testMostRecentSessionWinsWhateverTheOrderGiven() {
        let older = SessionSnapshot(finishedAt: day(1), sets: [set(bench, 1, 10, 100)])
        let newer = SessionSnapshot(finishedAt: day(5), sets: [set(bench, 1, 6, 150)])

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [newer, older])
        let reversed = DefaultSets.resolve(plannedExerciseID: bench, history: [older, newer])

        XCTAssertEqual(result.sets, [SetValues(reps: 6, weight: 150)])
        XCTAssertEqual(reversed, result)
    }

    func testExerciseSkippedLastSessionUsesTheSessionBefore() {
        let older = SessionSnapshot(finishedAt: day(1), sets: [set(bench, 1, 10, 100), set(fly, 1, 12, 30)])
        let newer = SessionSnapshot(finishedAt: day(5), sets: [set(fly, 1, 12, 35)])

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [older, newer])

        XCTAssertEqual(result.sets, [SetValues(reps: 10, weight: 100)])
        XCTAssertEqual(result.sourceDate, day(1))
    }

    func testExerciseNeverLoggedFallsBackEvenWithOtherHistory() {
        let last = SessionSnapshot(finishedAt: day(1), sets: [set(bench, 1, 10, 100)])

        let result = DefaultSets.resolve(plannedExerciseID: fly, history: [last])

        XCTAssertEqual(result.sets, DefaultSets.fallback)
        XCTAssertNil(result.sourceDate)
    }

    func testEmptyWeightStaysEmptyAndZeroStaysZero() {
        let last = SessionSnapshot(finishedAt: day(1), sets: [
            set(bench, 1, 12, nil),
            set(bench, 2, 12, 0),
        ])

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [last])

        XCTAssertNil(result.sets[0].weight)
        XCTAssertEqual(result.sets[1].weight, 0)
    }

    func testSameExerciseTwiceKeepsDefaultsPerPosition() {
        // Two positions in one workout are two planned exercises with their own ids.
        let first = UUID()
        let second = UUID()
        let last = SessionSnapshot(finishedAt: day(1), sets: [
            set(first, 1, 5, 185),
            set(second, 1, 15, 95),
            set(second, 2, 15, 95),
        ])

        XCTAssertEqual(
            DefaultSets.resolve(plannedExerciseID: first, history: [last]).sets,
            [SetValues(reps: 5, weight: 185)]
        )
        XCTAssertEqual(
            DefaultSets.resolve(plannedExerciseID: second, history: [last]).sets,
            [SetValues(reps: 15, weight: 95), SetValues(reps: 15, weight: 95)]
        )
    }

    func testSetsComeBackInSetNumberOrder() {
        let last = SessionSnapshot(finishedAt: day(1), sets: [
            set(bench, 3, 8, 130),
            set(bench, 1, 10, 135),
            set(bench, 2, 9, 135),
        ])

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [last])

        XCTAssertEqual(result.sets.map(\.reps), [10, 9, 8])
    }

    func testDecimalWeightsSurvive() {
        let last = SessionSnapshot(finishedAt: day(1), sets: [set(bench, 1, 10, 22.75)])

        let result = DefaultSets.resolve(plannedExerciseID: bench, history: [last])

        XCTAssertEqual(result.sets, [SetValues(reps: 10, weight: 22.75)])
    }
}

final class WeightFormatTests: XCTestCase {
    func testEmptyIsNoValueNotZero() {
        XCTAssertNil(WeightFormat.parse(""))
        XCTAssertEqual(WeightFormat.string(nil), "")
    }

    func testZeroIsARealValue() {
        XCTAssertEqual(WeightFormat.parse("0"), 0)
        XCTAssertEqual(WeightFormat.string(0), "0")
    }

    func testFormatsWithoutTrailingZeros() {
        XCTAssertEqual(WeightFormat.string(135), "135")
        XCTAssertEqual(WeightFormat.string(2.5), "2.5")
        XCTAssertEqual(WeightFormat.string(22.75), "22.75")
    }

    func testAcceptsCommaAsDecimalSeparator() {
        XCTAssertEqual(WeightFormat.parse("22,75"), 22.75)
    }

    func testSanitizeKeepsTwoDecimalPlaces() {
        XCTAssertEqual(WeightFormat.sanitize("22.758"), "22.75")
        XCTAssertEqual(WeightFormat.sanitize("1a3.5.2"), "13.52")
        XCTAssertEqual(WeightFormat.sanitize("135"), "135")
    }
}
