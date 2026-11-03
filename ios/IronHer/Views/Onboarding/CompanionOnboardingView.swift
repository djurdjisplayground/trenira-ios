import SwiftUI

/// Short companion questions. Skip saves a profile so the strength intro is not shown next.
struct CompanionPreferencesEditor: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CompanionOnboardingView(finishTitle: "Save") {
            dismiss()
        }
    }
}

struct CompanionOnboardingView: View {
    var finishTitle: String = "See your home"
    var onFinished: () -> Void

    @State private var step = 0
    @State private var goal: MovementGoal?
    @State private var barriers: [MovementBarrier] = []
    @State private var primaryBarrier: MovementBarrier?
    @State private var formats: [MovementFormat] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: TreniraSpace.section) {
                    Text(title)
                        .font(TreniraType.title)
                        .foregroundStyle(TreniraColor.label)
                        .accessibilityAddTraits(.isHeader)
                    Text(subtitle)
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    stepContent
                }
                .padding(.horizontal, TreniraSpace.screen)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            VStack(spacing: 10) {
                Text("\(step + 1) of 3")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(step == 2 ? finishTitle : "Continue", action: advance)
                    .buttonStyle(TreniraPrimaryButtonStyle())
                    .disabled(!canContinue)
                if step > 0 {
                    Button("Back") { step -= 1 }
                        .buttonStyle(TreniraSecondaryButtonStyle())
                }
                Button("Skip for now", action: skip)
                    .buttonStyle(TreniraSecondaryButtonStyle())
            }
            .padding(.horizontal, TreniraSpace.screen)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TreniraColor.canvas)
        .onAppear(perform: loadExisting)
    }

    private var title: String {
        switch step {
        case 0: "What would you like to achieve?"
        case 1: "What's getting in your way?"
        default: "What movement do you enjoy?"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: "Choose one. You can change this later."
        case 1: "Choose any that fit, then mark the biggest one."
        default: "Choose any that fit. Not sure is fine."
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            choiceList(MovementGoal.allCases, selected: { goal == $0 }) { item in
                goal = item
            }
        case 1:
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                ForEach(MovementBarrier.allCases) { item in
                    TreniraChoiceRow(
                        title: item.title,
                        detail: barrierDetail(item),
                        isSelected: barriers.contains(item)
                    ) {
                        toggleBarrier(item)
                    }
                }
            }
        default:
            choiceList(MovementFormat.allCases, selected: { formats.contains($0) }) { item in
                toggleFormat(item)
            }
        }
    }

    private var canContinue: Bool {
        switch step {
        case 0: goal != nil
        case 1: barriers.isEmpty || primaryBarrier != nil
        default: !formats.isEmpty
        }
    }

    private func barrierDetail(_ item: MovementBarrier) -> String? {
        if primaryBarrier == item { return "Biggest right now" }
        if barriers.contains(item) { return "Tap to make this the biggest" }
        return nil
    }

    private func advance() {
        if step < 2 {
            step += 1
        } else {
            persist(skipped: false)
            var properties: [String: String] = [:]
            if let barrier = primaryBarrier ?? barriers.first {
                properties["primary_barrier"] = barrier.rawValue
            }
            AnalyticsService.capture(.companionOnboardingCompleted, properties: properties)
            onFinished()
        }
    }

    private func skip() {
        persist(skipped: true)
        onFinished()
    }

    private func toggleBarrier(_ item: MovementBarrier) {
        if barriers.contains(item), primaryBarrier != item {
            primaryBarrier = item
            return
        }
        if barriers.contains(item) {
            barriers.removeAll { $0 == item }
            primaryBarrier = barriers.first
            return
        }
        barriers.append(item)
        if primaryBarrier == nil {
            primaryBarrier = item
        }
    }

    private func toggleFormat(_ item: MovementFormat) {
        if item == .notSure {
            formats = formats == [.notSure] ? [] : [.notSure]
            return
        }
        formats.removeAll { $0 == .notSure }
        if formats.contains(item) {
            formats.removeAll { $0 == item }
        } else {
            formats.append(item)
        }
    }

    private func loadExisting() {
        guard let saved = CompanionProfileStore.load() else { return }
        goal = saved.goal
        barriers = saved.barriers
        primaryBarrier = saved.primaryBarrier
        formats = saved.formats
    }

    private func persist(skipped: Bool) {
        let profile = CompanionProfile(
            goal: goal,
            barriers: barriers,
            primaryBarrier: primaryBarrier ?? barriers.first,
            formats: formats,
            skipped: skipped && goal == nil && barriers.isEmpty && formats.isEmpty
        )
        CompanionProfileStore.save(profile)
    }
}

private extension CompanionOnboardingView {
    func choiceList(_ items: [MovementGoal], selected: @escaping (MovementGoal) -> Bool, onTap: @escaping (MovementGoal) -> Void) -> some View {
        rows(items, title: { $0.title }, selected: selected, onTap: onTap)
    }

    func choiceList(_ items: [MovementFormat], selected: @escaping (MovementFormat) -> Bool, onTap: @escaping (MovementFormat) -> Void) -> some View {
        rows(items, title: { $0.title }, selected: selected, onTap: onTap)
    }

    func rows<Item: Identifiable>(
        _ items: [Item],
        title: @escaping (Item) -> String,
        selected: @escaping (Item) -> Bool,
        onTap: @escaping (Item) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: TreniraSpace.stack) {
            ForEach(items) { item in
                TreniraChoiceRow(title: title(item), isSelected: selected(item)) {
                    onTap(item)
                }
            }
        }
    }
}
