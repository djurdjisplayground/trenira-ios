import SwiftUI

struct ExploreMovementView: View {
    @Environment(UserDataCoordinator.self) private var dataCoordinator
    @State private var category: CatalogCategory?
    @State private var energy: MovementEnergy?
    @State private var equipment: MovementEquipment?
    @State private var maxMinutes: Int?
    @State private var favorites = MovementFavoriteStore.ids()

    private var ownerId: String { dataCoordinator.currentOwner.rawValue }

    private var babyNearby: [CatalogActivity] {
        MovementCatalog.all.filter { $0.category == .withBabyNearby && matchesFilters($0) }
    }

    private var showsBabyNearbySection: Bool {
        category == nil || category == .withBabyNearby
    }

    private var activities: [CatalogActivity] {
        MovementCatalog.all.filter { activity in
            if activity.category == .withBabyNearby { return false }
            if let category, activity.category != category { return false }
            return matchesFilters(activity)
        }
    }

    private func matchesFilters(_ activity: CatalogActivity) -> Bool {
        if let energy, !activity.energies.contains(energy) { return false }
        if let equipment, activity.equipment != equipment { return false }
        if let maxMinutes, activity.minimumMinutes > maxMinutes { return false }
        return true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: TreniraSpace.section) {
                Text("A small library")
                    .font(TreniraType.displayTitle)
                    .foregroundStyle(TreniraColor.label)
                    .accessibilityAddTraits(.isHeader)
                Text("A few general ideas. None of them is a program, and none uses a baby as equipment.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                filterRow("Category", categoryTitles, selected: category?.title) { title in
                    category = category?.title == title ? nil : CatalogCategory.allCases.first { $0.title == title }
                }
                filterRow("Energy", MovementEnergy.allCases.map(\.title), selected: energy?.title) { title in
                    energy = energy?.title == title ? nil : MovementEnergy.allCases.first { $0.title == title }
                }
                filterRow("Equipment", MovementEquipment.allCases.map(\.title), selected: equipment?.title) { title in
                    equipment = equipment?.title == title ? nil : MovementEquipment.allCases.first { $0.title == title }
                }
                filterRow("Time", ["2", "5", "10", "15", "20+"], selected: maxMinutes.map { $0 >= 20 ? "20+" : "\($0)" }) { title in
                    let value = title == "20+" ? 20 : Int(title)
                    maxMinutes = maxMinutes == value ? nil : value
                }
                if showsBabyNearbySection {
                    babyNearbySection
                }
                if category != .withBabyNearby {
                    ForEach(activities) { activity in
                        activityCard(activity, draft: false)
                    }
                    if activities.isEmpty {
                        Text("Nothing in this filter. Clear a chip to see more.")
                            .font(TreniraType.body)
                            .foregroundStyle(TreniraColor.labelSecondary)
                    }
                }
            }
            .padding(TreniraSpace.screen)
        }
        .background(TreniraColor.ivory)
        .navigationTitle("Explore")
        .navigationBarTitleDisplayMode(.inline)
        .profileToolbar()
    }

    private var categoryTitles: [String] {
        let nearby = CatalogCategory.withBabyNearby.title
        return [nearby] + CatalogCategory.allCases.map(\.title).filter { $0 != nearby }
    }

    private var babyNearbySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("With baby nearby")
                .font(TreniraType.displayTitle)
                .foregroundStyle(TreniraColor.label)
                .accessibilityAddTraits(.isHeader)
            Text("Draft. Your baby stays safely nearby and is not part of the movement. These ideas still need professional review before public release.")
                .font(TreniraType.body)
                .foregroundStyle(TreniraColor.labelSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if babyNearby.isEmpty {
                Text("Nothing in this filter for the time, energy, or equipment you chose.")
                    .font(TreniraType.body)
                    .foregroundStyle(TreniraColor.labelSecondary)
            } else {
                ForEach(babyNearby) { activity in
                    activityCard(activity, draft: true)
                }
            }
        }
    }

    private func activityCard(_ activity: CatalogActivity, draft: Bool) -> some View {
        HStack(alignment: .top, spacing: 8) {
            NavigationLink {
                MovementDetailView(
                    activity: activity,
                    query: RecommendationQuery(
                        minutes: max(activity.minimumMinutes, maxMinutes ?? 5),
                        energy: energy ?? activity.energies.first ?? .okay,
                        selection: .focused(activity.equipment),
                        preferred: [],
                        avoidFloor: CompanionProfileStore.load()?.avoidsFloor ?? false
                    ),
                    ownerId: ownerId,
                    source: .library
                )
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(activity.name)
                        .font(TreniraType.section)
                        .foregroundStyle(TreniraColor.label)
                    Text(cardDetail(activity, draft: draft))
                        .font(TreniraType.caption)
                        .foregroundStyle(TreniraColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button {
                MovementFavoriteStore.toggle(activity.id)
                favorites = MovementFavoriteStore.ids()
            } label: {
                Image(systemName: favorites.contains(activity.id) ? "heart.fill" : "heart")
                    .foregroundStyle(TreniraColor.orchid)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(favorites.contains(activity.id) ? "Remove favorite" : "Favorite")
        }
        .padding(TreniraSpace.cardPadding)
        .background(draft ? TreniraColor.lavender : TreniraColor.elevated)
        .clipShape(RoundedRectangle(cornerRadius: TreniraSpace.cardRadius, style: .continuous))
    }

    private func cardDetail(_ activity: CatalogActivity, draft: Bool) -> String {
        let base = "\(activity.category.title) · \(activity.durationLabel) · \(activity.equipment.title)"
        return draft ? "\(base) · Draft, review before release" : base
    }

    private func filterRow(
        _ title: String,
        _ choices: [String],
        selected: String?,
        onTap: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(TreniraType.caption)
                .foregroundStyle(TreniraColor.labelSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(choices, id: \.self) { choice in
                        Button(choice) { onTap(choice) }
                            .font(TreniraType.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selected == choice ? TreniraColor.action : TreniraColor.elevated)
                            .foregroundStyle(selected == choice ? TreniraColor.onAction : TreniraColor.label)
                            .clipShape(Capsule())
                            .accessibilityAddTraits(selected == choice ? .isSelected : [])
                    }
                }
            }
        }
    }
}
