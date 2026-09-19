import SwiftUI

/// Detailed multi-select equipment picker grouped by category.
struct GymEquipmentPicker: View {
    @Binding var selection: Set<GymEquipmentKind>
    var showsPresets: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsPresets {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick equipment sets")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                        ForEach(GymEquipmentPreset.allCases) { preset in
                            equipmentOptionChip(
                                title: preset.label,
                                isSelected: selection == preset.equipment
                            ) {
                                selection = preset.equipment
                            }
                        }
                    }
                }
            }

            ForEach(GymEquipmentCategory.allCases) { category in
                VStack(alignment: .leading, spacing: 10) {
                    Text(category.label)
                        .font(SheLiftsFont.section)
                        .foregroundStyle(IronHerTheme.primaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 8) {
                        ForEach(category.kinds) { kind in
                            equipmentChip(kind)
                        }
                    }
                }
            }
        }
    }

    private func equipmentChip(_ kind: GymEquipmentKind) -> some View {
        let selected = selection.contains(kind)
        return equipmentOptionChip(title: kind.label, isSelected: selected) {
            var next = selection
            if selected {
                next.remove(kind)
            } else {
                next.insert(kind)
            }
            selection = next
        }
    }

    private func equipmentOptionChip(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? IronHerTheme.accentForeground : IronHerTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? IronHerTheme.accent : IronHerTheme.groupedBackground)
                .clipShape(Capsule())
                .overlay {
                    if !isSelected {
                        Capsule()
                            .stroke(IronHerTheme.separator.opacity(0.85), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct GymProfilePickerRow: View {
    @Environment(GymEquipmentProfileStore.self) private var gymProfiles
    @Binding var selection: Set<GymEquipmentKind>

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gym profile")
                .font(SheLiftsFont.section)
                .foregroundStyle(IronHerTheme.primaryText)

            if gymProfiles.profiles.isEmpty {
                Text("Save a gym profile in Settings to reuse equipment setups.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(gymProfiles.profiles) { profile in
                            let isActive = gymProfiles.activeProfileId == profile.id
                            Button {
                                gymProfiles.selectProfile(profile.id)
                                selection = profile.availableEquipment
                            } label: {
                                Text(profile.name)
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(isActive ? IronHerTheme.accentForeground : IronHerTheme.primaryText)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isActive ? IronHerTheme.accent : IronHerTheme.cardBackground)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
