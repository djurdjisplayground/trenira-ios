import SwiftUI

/// Detailed multi-select equipment picker grouped by category.
struct GymEquipmentPicker: View {
    @Binding var selection: Set<GymEquipmentKind>
    var showsPresets: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if showsPresets {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Quick presets")
                        .font(SheLiftsFont.caption)
                        .foregroundStyle(IronHerTheme.secondaryText)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110))], spacing: 8) {
                        ForEach(GymEquipmentPreset.allCases) { preset in
                            Button {
                                selection = preset.equipment
                            } label: {
                                Text(preset.label)
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(IronHerTheme.cardBackground)
                                    .clipShape(Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
                                    }
                            }
                            .buttonStyle(.plain)
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
        return Button {
            if selected {
                selection.remove(kind)
            } else {
                selection.insert(kind)
            }
        } label: {
            Text(kind.label)
                .font(SheLiftsFont.caption)
                .foregroundStyle(selected ? IronHerTheme.accentForeground : IronHerTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? IronHerTheme.accent : IronHerTheme.cardBackground)
                .clipShape(Capsule())
                .overlay {
                    if !selected {
                        Capsule()
                            .stroke(IronHerTheme.separator.opacity(0.6), lineWidth: 0.5)
                    }
                }
        }
        .buttonStyle(.plain)
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
