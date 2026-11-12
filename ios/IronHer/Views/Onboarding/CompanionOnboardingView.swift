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

private struct PreferenceChoice: Identifiable {
    var id: String
    var title: String
    var kinds: [CatalogCategory]
    var format: MovementFormat?
}

struct CompanionOnboardingView: View {
    var finishTitle: String = "See Today"
    var onFinished: () -> Void

    @State private var step = 0
    @State private var selected: Set<String> = []
    @State private var equipment: Set<MovementEquipment> = []
    @State private var avoidFloor = false

    private let choices: [PreferenceChoice] = [
        PreferenceChoice(id: "strength", title: "Strength", kinds: [.dumbbellStrength, .bodyweightStrength], format: .strength),
        PreferenceChoice(id: "walking", title: "Walking", kinds: [.walking], format: .walking),
        PreferenceChoice(id: "yoga", title: "Yoga", kinds: [.yogaInspired], format: .yoga),
        PreferenceChoice(id: "stretching", title: "Stretching", kinds: [.stretching], format: nil),
        PreferenceChoice(id: "dance", title: "Dance", kinds: [.dancing], format: .dancing),
        PreferenceChoice(id: "mobility", title: "Mobility", kinds: [.mobility], format: nil),
        PreferenceChoice(id: "bodyweight", title: "Bodyweight", kinds: [.bodyweightStrength], format: .strength)
    ]

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
                Text("\(step + 1) of 4")
                    .font(TreniraType.caption)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(step == 3 ? finishTitle : "Continue", action: advance)
                    .buttonStyle(TreniraPrimaryButtonStyle())
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
        .background(TreniraColor.ivory)
        .onAppear(perform: loadExisting)
    }

    private var title: String {
        switch step {
        case 0: "What movement do you enjoy?"
        case 1: "What do you have nearby?"
        case 2: "Anything to leave out?"
        default: "Reminders are optional"
        }
    }

    private var subtitle: String {
        switch step {
        case 0: "Choose any that fit. You can skip this and still use Today."
        case 1: "Choose any you have nearby. On Today you pick one, or Surprise me."
        case 2: "This only hides floor-based ideas. It is not a health assessment."
        default: "A reminder can wait until you open Profile. trenira will not ask for notification permission here."
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                ForEach(choices) { choice in
                    TreniraChoiceRow(title: choice.title, isSelected: selected.contains(choice.id)) {
                        if selected.contains(choice.id) {
                            selected.remove(choice.id)
                        } else {
                            selected.insert(choice.id)
                        }
                    }
                }
            }
        case 1:
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                ForEach(MovementEquipment.allCases) { item in
                    TreniraChoiceRow(title: item.title, isSelected: equipment.contains(item)) {
                        if equipment.contains(item) {
                            equipment.remove(item)
                        } else {
                            equipment.insert(item)
                        }
                    }
                }
            }
        case 2:
            VStack(alignment: .leading, spacing: TreniraSpace.stack) {
                TreniraChoiceRow(title: "Avoid floor-based moves", isSelected: avoidFloor) {
                    avoidFloor.toggle()
                }
                Text(MovementCatalog.postpartumNote)
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.label)
                    .fixedSize(horizontal: false, vertical: true)
            }
        default:
            Text("You can turn a gentle reminder on later, at a time you choose. Nothing is scheduled until you do.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.label)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func advance() {
        if step < 3 {
            step += 1
        } else {
            persist(skipped: false)
            AnalyticsService.capture(.companionOnboardingCompleted, properties: [:])
            onFinished()
        }
    }

    private func skip() {
        persist(skipped: true)
        onFinished()
    }

    private func loadExisting() {
        guard let saved = CompanionProfileStore.load() else { return }
        equipment = Set(saved.equipment ?? [])
        avoidFloor = saved.avoidFloorMoves ?? false
        let kinds = Set(saved.preferredKinds ?? [])
        selected = Set(choices.filter { choice in
            choice.kinds.contains { kinds.contains($0.rawValue) }
        }.map(\.id))
    }

    private func persist(skipped: Bool) {
        let picked = choices.filter { selected.contains($0.id) }
        var formats: [MovementFormat] = []
        var kinds: [String] = []
        for choice in picked {
            kinds.append(contentsOf: choice.kinds.map(\.rawValue))
            if let format = choice.format, !formats.contains(format) {
                formats.append(format)
            }
        }
        let profile = CompanionProfile(
            formats: formats,
            skipped: skipped && picked.isEmpty && equipment.isEmpty,
            equipment: Array(equipment),
            avoidFloorMoves: avoidFloor,
            preferredKinds: Array(Set(kinds)).sorted()
        )
        CompanionProfileStore.save(profile)
    }
}
