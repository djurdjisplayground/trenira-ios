import Foundation

/// Stable, translator-agnostic keys for every piece of user-facing UI copy in trenira.
/// Raw values are snake_case and must never change once shipped — they are the
/// permanent lookup key into `UIStrings.table`, independent of English wording.
enum L10nKey: String, CaseIterable {
    // MARK: - Brand
    case tagline_line1 = "tagline_line1"
    case tagline_line2 = "tagline_line2"

    // MARK: - Auth / Welcome
    case welcome_sign_in_prompt = "welcome_sign_in_prompt"
    case continue_with_apple = "continue_with_apple"
    case continue_with_google = "continue_with_google"
    case continue_with_email = "continue_with_email"
    case continue_as_guest = "continue_as_guest"
    case sign_in = "sign_in"
    case create_account = "create_account"
    case email = "email"
    case password = "password"
    case cancel = "cancel"
    case welcome_back = "welcome_back"
    case create_your_account = "create_your_account"
    case save_workouts_progress = "save_workouts_progress"

    // MARK: - Home
    case good_morning = "good_morning"
    case good_afternoon = "good_afternoon"
    case good_evening = "good_evening"
    case welcome_guest = "welcome_guest"
    case welcome_signed_in = "welcome_signed_in"
    case welcome_signed_out = "welcome_signed_out"
    case start_workout = "start_workout"
    case my_workouts = "my_workouts"
    case create_workout = "create_workout"
    case edit_workout = "edit_workout"
    case track_this_week = "track_this_week"
    case progress_history = "progress_history"
    case my_progression = "my_progression"
    case settings = "settings"
    case home_tab = "home_tab"
    case workouts_tab = "workouts_tab"
    case workouts_tab_footer = "workouts_tab_footer"
    case build_and_adapt = "build_and_adapt"
    case build_tab = "build_tab"
    case adapt_tab = "adapt_tab"
    case adapt_tab_footer = "adapt_tab_footer"
    case adapt_workout = "adapt_workout"
    case adapt_workout_manual = "adapt_workout_manual"
    case regenerate_workout_ai_subtitle = "regenerate_workout_ai_subtitle"
    case starting_weight = "starting_weight"
    case starting_weight_caption = "starting_weight_caption"
    case weight_increment = "weight_increment"
    case exercise_increment_caption = "exercise_increment_caption"
    case exercise_no_weight_progression = "exercise_no_weight_progression"
    case create_manually = "create_manually"
    case create_manually_subtitle = "create_manually_subtitle"
    case generate_with_ai = "generate_with_ai"
    case create_workout_options_footer = "create_workout_options_footer"
    case home_create_subtitle = "home_create_subtitle"
    case home_track_week_empty = "home_track_week_empty"
    case home_track_week_cta = "home_track_week_cta"
    case what_improved = "what_improved"
    case track_this_week_empty_title = "track_this_week_empty_title"
    case track_this_week_empty_body = "track_this_week_empty_body"
    case track_this_week_no_improvements = "track_this_week_no_improvements"
    case track_this_week_improvements_footer = "track_this_week_improvements_footer"
    case home_track_week_accessibility_hint = "home_track_week_accessibility_hint"
    case set_increment = "set_increment"
    case custom = "custom"
    case increment_prompt_intro = "increment_prompt_intro"
    case increment_prompt_footer = "increment_prompt_footer"
    case standard_increments = "standard_increments"
    case standard_increments_footer = "standard_increments_footer"
    case machine_cable_increments = "machine_cable_increments"
    case machine_cable_increments_empty = "machine_cable_increments_empty"
    case machine_cable_increments_footer = "machine_cable_increments_footer"
    case exercise_increment_reset_footer = "exercise_increment_reset_footer"
    case results_section = "results_section"
    case progress_progression_footer = "progress_progression_footer"
    case progress_results_footer = "progress_results_footer"
    case my_workouts_empty_body = "my_workouts_empty_body"
    case build_and_adapt_intro_title = "build_and_adapt_intro_title"
    case build_and_adapt_intro_body = "build_and_adapt_intro_body"
    case build_workouts_section = "build_workouts_section"
    case adapt_workouts_section = "adapt_workouts_section"
    case progress_section = "progress_section"
    case progress_tab = "progress_tab"
    case progress_hub_footer = "progress_hub_footer"
    case progress_started = "progress_started"
    case progress_current = "progress_current"
    case progress_date_range = "progress_date_range"
    case progress_history_empty_body = "progress_history_empty_body"
    case progress_history_list_footer = "progress_history_list_footer"
    case progress_detail_footer = "progress_detail_footer"
    case equipment_increments_intro = "equipment_increments_intro"
    case equipment_increments_footer = "equipment_increments_footer"
    case equipment_increments_bodyweight_note = "equipment_increments_bodyweight_note"
    case equipment_increment_suggested = "equipment_increment_suggested"
    case equipment_increment_set_for_gym = "equipment_increment_set_for_gym"
    case your_increments = "your_increments"
    case increment = "increment"
    case reset = "reset"
    case home_start_empty_subtitle = "home_start_empty_subtitle"
    case home_build_adapt_subtitle = "home_build_adapt_subtitle"
    case continue_workout = "continue_workout"
    case continue_workout_subtitle = "continue_workout_subtitle"
    case start_again = "start_again"
    case start_again_subtitle = "start_again_subtitle"
    case choose_workout = "choose_workout"
    case choose_workout_footer = "choose_workout_footer"
    case in_progress = "in_progress"
    case my_workouts_library_footer = "my_workouts_library_footer"
    case generate_workout = "generate_workout"
    case generate_workout_subtitle = "generate_workout_subtitle"
    case regenerate_workout = "regenerate_workout"
    case regenerate_workout_subtitle = "regenerate_workout_subtitle"
    case adapt_existing_workout = "adapt_existing_workout"
    case adapt_existing_workout_subtitle = "adapt_existing_workout_subtitle"
    case default_progression_subtitle = "default_progression_subtitle"
    case equipment_increments_subtitle = "equipment_increments_subtitle"
    case deload_behaviour = "deload_behaviour"
    case deload_behaviour_subtitle = "deload_behaviour_subtitle"
    case build_progression_footer = "build_progression_footer"
    case start_workout_subtitle = "start_workout_subtitle"
    case my_workouts_subtitle = "my_workouts_subtitle"
    case create_workout_subtitle = "create_workout_subtitle"
    case edit_workout_subtitle = "edit_workout_subtitle"
    case track_this_week_subtitle = "track_this_week_subtitle"
    case progress_history_subtitle = "progress_history_subtitle"
    case my_progression_subtitle = "my_progression_subtitle"
    case settings_subtitle = "settings_subtitle"

    // MARK: - Workouts
    case workouts = "workouts"
    case exercises = "exercises"
    case exercise = "exercise"
    case sets = "sets"
    case reps = "reps"
    case weight = "weight"
    case duration = "duration"
    case distance = "distance"
    case notes = "notes"
    case add_exercise = "add_exercise"
    case remove = "remove"
    case save = "save"
    case delete = "delete"
    case done = "done"
    case next = "next"
    case back = "back"
    case close = "close"
    case start = "start"
    case finish_set = "finish_set"
    case finish_exercise = "finish_exercise"
    case finish_workout = "finish_workout"
    case skip = "skip"
    case rest = "rest"
    case empty_workouts_title = "empty_workouts_title"
    case empty_workouts_body = "empty_workouts_body"
    case workout_complete = "workout_complete"
    case back_to_home = "back_to_home"
    case active_workout = "active_workout"
    case target = "target"
    case logged = "logged"
    case bodyweight = "bodyweight"

    // MARK: - Progression
    case progression = "progression"
    case progression_rules = "progression_rules"
    case progression_rules_subtitle = "progression_rules_subtitle"
    case progression_rules_intro = "progression_rules_intro"
    case progression_strength_footer = "progression_strength_footer"
    case progression_bodyweight_footer = "progression_bodyweight_footer"
    case progression_timed_footer = "progression_timed_footer"
    case default_increments = "default_increments"
    case default_increments_footer = "default_increments_footer"
    case rep_increment_value = "rep_increment_value"
    case time_increment_value = "time_increment_value"
    case progression_rule = "progression_rule"
    case progression_rule_footer = "progression_rule_footer"
    case exercise_weight_increment_footer = "exercise_weight_increment_footer"
    case progress_history_section_footer = "progress_history_section_footer"
    case default_progression = "default_progression"
    case custom_progressions = "custom_progressions"
    case add_custom_progression = "add_custom_progression"
    case you_decide_progress = "you_decide_progress"

    // MARK: - Settings
    case membership = "membership"
    case units = "units"
    case weight_unit = "weight_unit"
    case appearance = "appearance"
    case theme = "theme"
    case notifications = "notifications"
    case session_feedback = "session_feedback"
    case style = "style"
    case progression_section = "progression_section"
    case equipment_increments = "equipment_increments"
    case current_plan = "current_plan"
    case view_premium = "view_premium"
    case manage_premium = "manage_premium"
    case switch_to_free = "switch_to_free"
    case free_premium_blurb = "free_premium_blurb"
    case kilograms_kg = "kilograms_kg"
    case pounds_lb = "pounds_lb"
    case system = "system"
    case light = "light"
    case dark = "dark"
    case minimal = "minimal"
    case encouragement = "encouragement"
    case coaching_minimal_detail = "coaching_minimal_detail"
    case coaching_encouragement_detail = "coaching_encouragement_detail"
    case progress_reminders = "progress_reminders"
    case progress_reminders_coming_soon = "progress_reminders_coming_soon"
    case exercise_library = "exercise_library"
    case browse_exercises = "browse_exercises"

    // MARK: - Subscription / Premium
    case premium = "premium"
    case free = "free"
    case progress_with_less_thinking = "progress_with_less_thinking"
    case premium_header_body = "premium_header_body"
    case you_have_premium = "you_have_premium"
    case upgrade_to_premium = "upgrade_to_premium"

    // MARK: - History
    case history = "history"
    case no_history_yet = "no_history_yet"

    // MARK: - Common
    case ok = "ok"
    case error = "error"
    case loading = "loading"
    case search = "search"
    case search_exercises = "search_exercises"
    case sign_out = "sign_out"
    case sign_in_title = "sign_in_title"
    case premium_badge = "premium_badge"

    // MARK: - Return after break
    case welcome_back_training = "welcome_back_training"
    case welcome_back_days = "welcome_back_days"
    case welcome_back_weeks = "welcome_back_weeks"
    case welcome_back_body_mild = "welcome_back_body_mild"
    case welcome_back_body_suggest = "welcome_back_body_suggest"
    case welcome_back_body_suggest_weight = "welcome_back_body_suggest_weight"
    case welcome_back_body_strong = "welcome_back_body_strong"
    case welcome_back_body_strong_weight = "welcome_back_body_strong_weight"
    case continue_with_current_weight = "continue_with_current_weight"
    case continue_with_weight = "continue_with_weight"
    case start_lighter = "start_lighter"
    case ready_when_you_are = "ready_when_you_are"
    case take_it_at_your_pace = "take_it_at_your_pace"
    case continue_where_you_left_off = "continue_where_you_left_off"
    case lighter_start_title = "lighter_start_title"
    case lighter_start_subtitle = "lighter_start_subtitle"
    case begin_workout = "begin_workout"
}

/// Central UI copy table for trenira. Keys are stable `L10nKey` values.
/// MVP is English-only; missing keys fall back to the raw key so the UI never renders empty text.
enum UIStrings {
    /// English copy for MVP. Reintroduce `[AppLanguage: …]` tables when localization returns.
    static let english: [L10nKey: String] = [
            // Brand
            .tagline_line1: "Strength,",
            .tagline_line2: "on your own terms.",

            // Auth / Welcome
            .welcome_sign_in_prompt: "Sign in to keep your workouts and progress with you.",
            .continue_with_apple: "Continue with Apple",
            .continue_with_google: "Continue with Google",
            .continue_with_email: "Continue with Email",
            .continue_as_guest: "Continue as Guest",
            .sign_in: "Sign In",
            .create_account: "Create Account",
            .email: "Email",
            .password: "Password",
            .cancel: "Cancel",
            .welcome_back: "Welcome Back",
            .create_your_account: "Create Your Account",
            .save_workouts_progress: "Keep your workouts and progress with you",

            // Home
            .good_morning: "Good morning",
            .good_afternoon: "Good afternoon",
            .good_evening: "Good evening",
            .welcome_guest: "Strength, on your own terms.",
            .welcome_signed_in: "Welcome back, %@",
            .welcome_signed_out: "Browsing as a guest — your training, your pace.",
            .start_workout: "Start Workout",
            .my_workouts: "My Workouts",
            .create_workout: "Create Workout",
            .edit_workout: "Edit Workout",
            .track_this_week: "Track This Week",
            .progress_history: "Progress History",
            .my_progression: "My Progression",
            .settings: "Settings",
            .home_tab: "Home",
            .workouts_tab: "Workouts",
            .workouts_tab_footer: "Choose a workout and start when you're ready.",
            .build_and_adapt: "Build",
            .build_tab: "Build",
            .build_and_adapt_intro_title: "Customize your training",
            .build_and_adapt_intro_body: "Create, adapt, and improve your workouts.",
            .build_workouts_section: "Create",
            .adapt_workouts_section: "Adapt",
            .progress_section: "Progress",
            .home_start_empty_subtitle: "Create a workout in My Workouts, then start here",
            .home_build_adapt_subtitle: "Create, adapt, and improve your workouts.",
            .continue_workout: "Continue Workout",
            .continue_workout_subtitle: "Resume your active session",
            .start_again: "Start Again",
            .start_again_subtitle: "Begin another session",
            .choose_workout: "Choose Workout",
            .choose_workout_footer: "Select a workout to start training.",
            .in_progress: "In progress",
            .my_workouts_library_footer: "Create, edit, or delete workouts here. Start training from Home.",
            .generate_workout: "Generate Workout",
            .generate_workout_subtitle: "Draft a plan from your goals and equipment",
            .regenerate_workout: "Regenerate Workout",
            .regenerate_workout_subtitle: "Fresh exercises, same training intention",
            .adapt_existing_workout: "Adapt Existing Workout",
            .adapt_existing_workout_subtitle: "Change exercises when equipment or conditions change",
            .default_progression_subtitle: "How weight, reps, sets, or time move forward",
            .equipment_increments_subtitle: "Plate steps and saved machine increments",
            .deload_behaviour: "Deload behaviour",
            .deload_behaviour_subtitle: "Coming soon",
            .build_progression_footer: "How trenira advances your training over time.",
            .start_workout_subtitle: "Choose a workout and begin training",
            .my_workouts_subtitle: "Edit and organize your plans",
            .create_workout_subtitle: "Add a new routine",
            .edit_workout_subtitle: "Adjust exercises and sets",
            .track_this_week_subtitle: "See what improved",
            .progress_history_subtitle: "See how you’ve improved",
            .my_progression_subtitle: "Where you're going next",
            .settings_subtitle: "Membership, units, and preferences",

            // Workouts
            .workouts: "Workouts",
            .exercises: "Exercises",
            .exercise: "Exercise",
            .sets: "Sets",
            .reps: "Reps",
            .weight: "Weight",
            .duration: "Duration",
            .distance: "Distance",
            .notes: "Notes",
            .add_exercise: "Add Exercise",
            .remove: "Remove",
            .save: "Save",
            .delete: "Delete",
            .done: "Done",
            .next: "Next",
            .back: "Back",
            .close: "Close",
            .start: "Start",
            .finish_set: "Finish Set",
            .finish_exercise: "Finish Exercise",
            .finish_workout: "Finish Workout",
            .skip: "Skip",
            .rest: "Rest",
            .empty_workouts_title: "No Workouts Yet",
            .empty_workouts_body: "Create a workout and start training on your terms.",
            .workout_complete: "Workout Complete",
            .back_to_home: "Back to Home",
            .active_workout: "Active Workout",
            .target: "Target",
            .logged: "Logged",
            .bodyweight: "Bodyweight",

            // Progression
            .progression: "Progression",
            .default_progression: "Default Progression",
            .custom_progressions: "Custom Progressions",
            .add_custom_progression: "Add Custom Progression",
            .you_decide_progress: "You define how you progress — trenira remembers.",

            // Settings
            .membership: "Membership",
            .units: "Units",
            .weight_unit: "Weight Unit",
            .appearance: "Appearance",
            .theme: "Theme",
            .notifications: "Notifications",
            .session_feedback: "Session Feedback",
            .style: "Style",
            .progression_section: "Progression",
            .equipment_increments: "Equipment Increments",
            .current_plan: "Current Plan",
            .view_premium: "View Premium",
            .manage_premium: "Manage Premium",
            .switch_to_free: "Switch to Free",
            .free_premium_blurb: "Free: everything you need to track your workouts. Premium: go beyond tracking.",
            .kilograms_kg: "Kilograms (kg)",
            .pounds_lb: "Pounds (lb)",
            .system: "System",
            .light: "Light",
            .dark: "Dark",
            .minimal: "Minimal",
            .encouragement: "Encouragement",
            .coaching_minimal_detail: "Brief, quiet cues during your workout.",
            .coaching_encouragement_detail: "Steady encouragement to help you stay consistent.",
            .progress_reminders: "Progress Reminders",
            .progress_reminders_coming_soon: "Coming soon",
            .exercise_library: "Exercise Library",
            .browse_exercises: "Browse Exercises",

            // Subscription / Premium
            .premium: "Premium",
            .free: "Free",
            .progress_with_less_thinking: "Go beyond tracking.",
            .premium_header_body: "Unlimited workouts, clearer progress insights, and calm tools that help you build and adapt — while you stay in control.",
            .you_have_premium: "You have Premium",
            .upgrade_to_premium: "Upgrade to Premium",

            // History
            .progress_tab: "Progress",
            .progress_hub_footer: "Progression and results in one place.",
            .progress_started: "Started",
            .progress_current: "Current",
            .progress_date_range: "Date range",
            .progress_history_empty_body: "Complete workouts to see how your strength improves over time.",
            .progress_history_list_footer: "Started to current — not every set.",
            .progress_detail_footer: "A simple view of how this exercise has progressed.",
            .equipment_increments_intro: "Weight increments belong to each exercise. Set them when you add a machine or cable, or in Exercise Library.",
            .equipment_increments_footer: "Used when progressive overload increases weight after a completed workout.",
            .equipment_increments_bodyweight_note: "No automatic weight increase. Progress through reps, sets, tempo, or added load.",
            .equipment_increment_suggested: "Common starting point: %@",
            .equipment_increment_set_for_gym: "Set to match your gym’s equipment.",
            .your_increments: "Your increments",
            .increment: "Increment",
            .reset: "Reset",
            .adapt_tab: "Adapt",
            .adapt_tab_footer: "Adjust workouts you already have for different situations.",
            .adapt_workout: "Adapt Workout",
            .create_manually: "Create Manually",
            .create_manually_subtitle: "Build your plan exercise by exercise",
            .generate_with_ai: "Generate with AI",
            .create_workout_options_footer: "AI is optional — create manually anytime.",
            .home_create_subtitle: "Build a new plan",
            .results_section: "Results",
            .progress_progression_footer: "Rules for how exercises progress — not the size of each step.",
            .progress_results_footer: "Recent improvements and long-term progress.",
            .my_workouts_empty_body: "Create your first workout to build your library.",
            .home_track_week_empty: "Complete workouts to see this week’s improvements here.",
            .home_track_week_accessibility_hint: "Opens Progress",
            .set_increment: "Set Increment",
            .custom: "Custom",
            .increment_prompt_intro: "Machines and cables vary by gym. Choose the weight step you use for this exercise.",
            .increment_prompt_footer: "Saved for this exercise. Edit anytime in Settings → Exercise Library.",
            .standard_increments: "Barbell & dumbbell",
            .standard_increments_footer: "Typical plate and dumbbell steps.",
            .machine_cable_increments: "Machines & cables",
            .machine_cable_increments_empty: "Increments are set the first time you add a machine or cable exercise.",
            .machine_cable_increments_footer: "Edit saved increments for exercises you’ve already set up.",
            .exercise_increment_reset_footer: "Clears the saved increment. You’ll be asked again next time you add this exercise.",
            .adapt_workout_manual: "Adapt Workout",
            .regenerate_workout_ai_subtitle: "Fresh exercises with AI — same training intention",
            .starting_weight: "Starting Weight",
            .starting_weight_caption: "Your current working weight for this exercise.",
            .weight_increment: "Weight Increment",
            .exercise_increment_caption: "Used when this exercise progresses. Each exercise can use a different step.",
            .exercise_no_weight_progression: "This exercise does not use automatic weight increases. Progress through reps, sets, or tempo.",
            .progression_rules: "Progression Rules",
            .progression_rules_subtitle: "How exercises progress by default",
            .progression_rules_intro: "Progression defines how an exercise moves forward. Increments define by how much.",
            .progression_strength_footer: "Weighted strength work — progress by weight, reps, or sets.",
            .progression_bodyweight_footer: "Bodyweight work — progress by reps or sets.",
            .progression_timed_footer: "Holds and timed efforts — progress by time.",
            .default_increments: "Default Increments",
            .default_increments_footer: "Used unless an exercise overrides them.",
            .rep_increment_value: "+%d reps",
            .time_increment_value: "+%d seconds",
            .progression_rule: "Progression Rule",
            .progression_rule_footer: "Overrides the category default for this exercise.",
            .exercise_weight_increment_footer: "Saved on this exercise. Shown only when progressing by weight.",
            .progress_history_section_footer: "Long-term improvements across your training.",
            .home_track_week_cta: "See your progress →",
            .what_improved: "What improved",
            .track_this_week_empty_title: "No workouts yet",
            .track_this_week_empty_body: "Complete a workout to see this week’s improvements.",
            .track_this_week_no_improvements: "No meaningful improvements logged yet this week.",
            .track_this_week_improvements_footer: "Weight and rep increases on primary lifts.",
            .history: "History",
            .no_history_yet: "No history yet",

            // Common
            .ok: "OK",
            .error: "Error",
            .loading: "Loading…",
            .search: "Search",
            .search_exercises: "Search Exercises",
            .sign_out: "Sign Out",
            .sign_in_title: "Sign in to trenira",
            .premium_badge: "Premium",

            // Return after break
            .welcome_back_training: "Welcome back",
            .welcome_back_days: "It's been %d days since your last workout.",
            .welcome_back_weeks: "It's been %d weeks since your last workout.",
            .welcome_back_body_mild: "Ready when you are. Continue where you left off, or take it lighter today.",
            .welcome_back_body_suggest: "How would you like to start today?",
            .welcome_back_body_suggest_weight: "You were previously lifting %@. How would you like to start today?",
            .welcome_back_body_strong: "It's been a longer break. Consider starting lighter today — you're always in control.",
            .welcome_back_body_strong_weight: "You were previously lifting %@. Consider starting lighter today — you're always in control. How would you like to start?",
            .continue_with_current_weight: "Continue with current weight",
            .continue_with_weight: "Continue with %@",
            .start_lighter: "Start lighter",
            .ready_when_you_are: "Ready when you are.",
            .take_it_at_your_pace: "Take it at your own pace.",
            .continue_where_you_left_off: "Continue where you left off.",
            .lighter_start_title: "Start lighter",
            .lighter_start_subtitle: "Adjust weights for today only. Your progression rules stay the same until you finish this workout.",
            .begin_workout: "Begin workout",
    ]
}

extension UIStrings {
    static func string(_ key: L10nKey, language: AppLanguage = .english) -> String {
        // `language` reserved for future multi-language support.
        _ = language
        return english[key] ?? key.rawValue
    }
}
