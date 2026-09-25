import KimbiaKit
import SwiftUI

/// "1 workout", "3 workouts".
func workoutCount(_ count: Int) -> String {
    count == 1 ? String(localized: "1 workout") : String(localized: "\(count) workouts")
}

/// "1 activity", "3 activities".
func activityCount(_ count: Int) -> String {
    count == 1 ? String(localized: "1 activity") : String(localized: "\(count) activities")
}

/// One workout: its icon, type, when, and how far and long.
struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.activityType.name)
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: workout.activityType.symbolName)
                .foregroundStyle(.tint)
        }
    }

    private var summary: String {
        var parts = [workout.start.formatted(date: .abbreviated, time: .shortened)]
        if let distance = workout.distance, distance > 0 {
            parts.append(Measurement(value: distance, unit: UnitLength.meters)
                .formatted(.measurement(width: .abbreviated, usage: .road, numberFormatStyle: .number.precision(.fractionLength(0 ... 2)))))
        }
        parts.append(Duration.seconds(workout.duration).formatted(.time(pattern: workout.duration >= 3600 ? .hourMinuteSecond : .minuteSecond)))
        return parts.joined(separator: " · ")
    }
}
