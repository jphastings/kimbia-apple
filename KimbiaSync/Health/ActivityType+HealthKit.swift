import HealthKit
import KimbiaKit

/// Names and symbols for HealthKit's activity types.
extension ActivityType {
    init(_ type: HKWorkoutActivityType) {
        self.init(rawValue: type.rawValue)
    }

    var healthKitType: HKWorkoutActivityType? {
        HKWorkoutActivityType(rawValue: rawValue)
    }

    /// Every type HealthKit knows, in alphabetical order of name, for
    /// choosing a type before you have ever done it.
    static let all: [ActivityType] = (UInt(1) ... 100).map(ActivityType.init(rawValue:))
        .filter { $0.knownName != nil && !retired.contains($0.rawValue) }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        + [ActivityType(.other)]

    /// Types HealthKit no longer records but that older workouts may have.
    private static let retired: Set<UInt> = [14, 15, 30]

    /// "Running", "Walking", "Other" …
    var name: String {
        knownName ?? String(localized: "Other")
    }

    /// The name HealthKit's own apps use, or `nil` for a type this build of
    /// the app doesn't know (or a retired one).
    private var knownName: String? {
        switch rawValue {
        // Retired types (dance, dance-inspired training, mixed metabolic
        // cardio) still appear in older Health data; matched by number to
        // avoid deprecation warnings.
        case 14: return String(localized: "Dance")
        case 15: return String(localized: "Dance-Inspired Training")
        case 30: return String(localized: "Mixed Metabolic Cardio")
        default: break
        }
        guard let type = healthKitType else { return nil }
        switch type {
        case .americanFootball: return String(localized: "American Football")
        case .archery: return String(localized: "Archery")
        case .australianFootball: return String(localized: "Australian Football")
        case .badminton: return String(localized: "Badminton")
        case .baseball: return String(localized: "Baseball")
        case .basketball: return String(localized: "Basketball")
        case .bowling: return String(localized: "Bowling")
        case .boxing: return String(localized: "Boxing")
        case .climbing: return String(localized: "Climbing")
        case .cricket: return String(localized: "Cricket")
        case .crossTraining: return String(localized: "Cross Training")
        case .curling: return String(localized: "Curling")
        case .cycling: return String(localized: "Cycling")
        case .elliptical: return String(localized: "Elliptical")
        case .equestrianSports: return String(localized: "Equestrian Sports")
        case .fencing: return String(localized: "Fencing")
        case .fishing: return String(localized: "Fishing")
        case .functionalStrengthTraining: return String(localized: "Functional Strength Training")
        case .golf: return String(localized: "Golf")
        case .gymnastics: return String(localized: "Gymnastics")
        case .handball: return String(localized: "Handball")
        case .hiking: return String(localized: "Hiking")
        case .hockey: return String(localized: "Hockey")
        case .hunting: return String(localized: "Hunting")
        case .lacrosse: return String(localized: "Lacrosse")
        case .martialArts: return String(localized: "Martial Arts")
        case .mindAndBody: return String(localized: "Mind and Body")
        case .paddleSports: return String(localized: "Paddle Sports")
        case .play: return String(localized: "Play")
        case .preparationAndRecovery: return String(localized: "Preparation and Recovery")
        case .racquetball: return String(localized: "Racquetball")
        case .rowing: return String(localized: "Rowing")
        case .rugby: return String(localized: "Rugby")
        case .running: return String(localized: "Running")
        case .sailing: return String(localized: "Sailing")
        case .skatingSports: return String(localized: "Skating")
        case .snowSports: return String(localized: "Snow Sports")
        case .soccer: return String(localized: "Football")
        case .softball: return String(localized: "Softball")
        case .squash: return String(localized: "Squash")
        case .stairClimbing: return String(localized: "Stair Climbing")
        case .surfingSports: return String(localized: "Surfing")
        case .swimming: return String(localized: "Swimming")
        case .tableTennis: return String(localized: "Table Tennis")
        case .tennis: return String(localized: "Tennis")
        case .trackAndField: return String(localized: "Track and Field")
        case .traditionalStrengthTraining: return String(localized: "Traditional Strength Training")
        case .volleyball: return String(localized: "Volleyball")
        case .walking: return String(localized: "Walking")
        case .waterFitness: return String(localized: "Water Fitness")
        case .waterPolo: return String(localized: "Water Polo")
        case .waterSports: return String(localized: "Water Sports")
        case .wrestling: return String(localized: "Wrestling")
        case .yoga: return String(localized: "Yoga")
        case .barre: return String(localized: "Barre")
        case .coreTraining: return String(localized: "Core Training")
        case .crossCountrySkiing: return String(localized: "Cross-Country Skiing")
        case .downhillSkiing: return String(localized: "Downhill Skiing")
        case .flexibility: return String(localized: "Flexibility")
        case .highIntensityIntervalTraining: return String(localized: "High-Intensity Interval Training")
        case .jumpRope: return String(localized: "Jump Rope")
        case .kickboxing: return String(localized: "Kickboxing")
        case .pilates: return String(localized: "Pilates")
        case .snowboarding: return String(localized: "Snowboarding")
        case .stairs: return String(localized: "Stairs")
        case .stepTraining: return String(localized: "Step Training")
        case .wheelchairWalkPace: return String(localized: "Wheelchair Walk Pace")
        case .wheelchairRunPace: return String(localized: "Wheelchair Run Pace")
        case .taiChi: return String(localized: "Tai Chi")
        case .mixedCardio: return String(localized: "Mixed Cardio")
        case .handCycling: return String(localized: "Hand Cycling")
        case .discSports: return String(localized: "Disc Sports")
        case .fitnessGaming: return String(localized: "Fitness Gaming")
        case .cardioDance: return String(localized: "Cardio Dance")
        case .socialDance: return String(localized: "Social Dance")
        case .pickleball: return String(localized: "Pickleball")
        case .cooldown: return String(localized: "Cooldown")
        case .swimBikeRun: return String(localized: "Multisport")
        case .transition: return String(localized: "Transition")
        case .underwaterDiving: return String(localized: "Underwater Diving")
        case .other: return nil
        @unknown default: return nil
        }
    }

    /// An SF Symbol for the type.
    var symbolName: String {
        guard let type = healthKitType else { return "figure.mixed.cardio" }
        switch type {
        case .running, .trackAndField: return "figure.run"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .cycling: return "figure.outdoor.cycle"
        case .handCycling: return "figure.hand.cycling"
        case .swimming: return "figure.pool.swim"
        case .swimBikeRun: return "figure.open.water.swim"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing, .stairs: return "figure.stair.stepper"
        case .yoga: return "figure.yoga"
        case .pilates: return "figure.pilates"
        case .mindAndBody, .taiChi: return "figure.mind.and.body"
        case .flexibility, .preparationAndRecovery, .cooldown: return "figure.flexibility"
        case .functionalStrengthTraining: return "figure.strengthtraining.functional"
        case .traditionalStrengthTraining: return "figure.strengthtraining.traditional"
        case .coreTraining: return "figure.core.training"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .crossTraining: return "figure.cross.training"
        case .climbing: return "figure.climbing"
        case .downhillSkiing: return "figure.skiing.downhill"
        case .crossCountrySkiing: return "figure.skiing.crosscountry"
        case .snowboarding: return "figure.snowboarding"
        case .soccer: return "figure.soccer"
        case .tennis: return "figure.tennis"
        case .golf: return "figure.golf"
        case .basketball: return "figure.basketball"
        case .boxing, .kickboxing: return "figure.boxing"
        case .cardioDance, .socialDance: return "figure.dance"
        case .wheelchairWalkPace, .wheelchairRunPace: return "figure.roll"
        case .paddleSports: return "figure.outdoor.rowing"
        case .surfingSports: return "figure.surfing"
        case .sailing: return "sailboat"
        default: return "figure.mixed.cardio"
        }
    }
}
