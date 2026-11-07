/// Built-in behaviors offered during setup.
///
/// Core behaviors start switched on; everything else is opt-in. Users can also
/// create their own behaviors, which use the same `Behavior` type.
public enum PresetLibrary {
    public static let core: [Behavior] = [
        p("sleep", "Sleep", .target, .body, "bed.double.fill", unit: "hours", target: 8, core: true),
        p("alcohol_free", "Alcohol-free", .avoid, .body, "wineglass", core: true),
        p("exercise", "Exercise 30+ min", .check, .body, "figure.run", core: true),
        p("hydration", "Hydration", .target, .body, "drop.fill", unit: "glasses", target: 8, core: true),
    ]

    public static let library: [Behavior] = [
        // Body
        p("steps", "Steps", .target, .body, "shoeprints.fill", unit: "steps", target: 8_000),
        p("strength", "Strength training", .check, .body, "dumbbell.fill"),
        p("pushups", "Pushups", .volume, .body, "figure.strengthtraining.traditional", unit: "reps", target: 50),
        p("stretch", "Stretch or mobility", .check, .body, "figure.flexibility"),
        p("vegetables", "Eat vegetables", .target, .body, "carrot.fill", unit: "servings", target: 3),
        p("no_junk_food", "No junk food", .avoid, .body, "takeoutbag.and.cup.and.straw.fill"),
        p("no_sugary_drinks", "No sugary drinks", .avoid, .body, "cup.and.saucer.fill"),
        p("no_smoking", "No smoking or vaping", .avoid, .body, "nosign"),
        p("caffeine_cutoff", "No caffeine after 2pm", .avoid, .body, "mug.fill"),
        p("sunlight", "Morning sunlight", .check, .body, "sun.max.fill"),

        // Mind
        p("meditate", "Meditate", .volume, .mind, "brain.head.profile", unit: "minutes", target: 10),
        p("read", "Read", .volume, .mind, "book.fill", unit: "pages", target: 20),
        p("study", "Study", .volume, .mind, "graduationcap.fill", unit: "minutes", target: 60),
        p("journal", "Journal", .check, .mind, "pencil.and.scribble"),
        p("gratitude", "Gratitude list", .check, .mind, "heart.text.square.fill"),
        p("screen_time", "Screen time", .target, .mind, "iphone", unit: "hours", target: 3, direction: .atMost),
        p("no_doomscrolling", "No doomscrolling", .avoid, .mind, "iphone.slash"),
        p("learn_language", "Language practice", .volume, .mind, "character.bubble.fill", unit: "minutes", target: 15),
        p("no_phone_in_bed", "No phone in bed", .avoid, .mind, "bed.double"),

        // Social
        p("call_friend", "Reach out to a friend or family", .check, .social, "phone.fill"),
        p("quality_time", "Quality time with others", .check, .social, "person.2.fill"),
        p("kind_act", "Act of kindness", .check, .social, "hands.sparkles.fill"),
        p("no_gossip", "No gossip or complaining", .avoid, .social, "bubble.left.and.exclamationmark.bubble.right.fill"),
        p("volunteer", "Volunteer", .volume, .social, "heart.circle.fill", unit: "hours", target: 1),

        // Work
        p("deep_work", "Deep work", .volume, .work, "target", unit: "minutes", target: 90),
        p("plan_day", "Plan tomorrow", .check, .work, "checklist"),
        p("inbox_zero", "Inbox zero", .check, .work, "tray.fill"),
        p("side_project", "Side project", .volume, .work, "hammer.fill", unit: "minutes", target: 30),
        p("no_procrastination", "No procrastination", .avoid, .work, "hourglass"),
        p("budget", "Track spending", .check, .work, "dollarsign.circle.fill"),
        p("no_impulse_buys", "No impulse buys", .avoid, .work, "cart.fill"),
    ]

    public static var all: [Behavior] { core + library }

    private static func p(
        _ id: String,
        _ name: String,
        _ kind: BehaviorKind,
        _ category: BehaviorCategory,
        _ icon: String,
        unit: String? = nil,
        target: Double? = nil,
        direction: TargetDirection = .atLeast,
        core: Bool = false
    ) -> Behavior {
        Behavior(
            id: id, name: name, kind: kind, category: category, icon: icon,
            unit: unit, target: target, direction: direction,
            isCore: core, isEnabled: core
        )
    }
}
