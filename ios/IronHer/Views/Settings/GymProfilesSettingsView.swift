import SwiftUI

struct GymProfilesSettingsView: View {
    @Environment(GymEquipmentProfileStore.self) private var gymProfiles
    @Environment(UserSettingsStore.self) private var settingsStore
    @State private var editingProfile: GymEquipmentProfile?
    @State private var showEditor = false

    var body: some View {
        List {
            Section {
                Text("Save equipment for each place you train. Generate and adapt workouts can use the active profile.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("Profiles") {
                ForEach(gymProfiles.profiles) { profile in
                    Button {
                        editingProfile = profile
                        showEditor = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(SheLiftsFont.bodyMedium)
                                    .foregroundStyle(IronHerTheme.primaryText)
                                Text("\(profile.availableEquipment.count) items · \(profile.defaultWeightUnit.shortLabel)")
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                            Spacer()
                            if gymProfiles.activeProfileId == profile.id {
                                Text("Active")
                                    .font(SheLiftsFont.caption)
                                    .foregroundStyle(IronHerTheme.secondaryText)
                            }
                        }
                    }
                    .swipeActions {
                        Button("Use") {
                            gymProfiles.selectProfile(profile.id)
                        }
                        Button("Delete", role: .destructive) {
                            gymProfiles.delete(id: profile.id)
                        }
                    }
                }

                Button("Add gym profile") {
                    editingProfile = GymEquipmentProfile(
                        name: "New Gym",
                        availableEquipment: GymEquipmentPreset.hotelGym.equipment,
                        defaultWeightUnit: settingsStore.weightUnit
                    )
                    showEditor = true
                }
            }
        }
        .navigationTitle("Gym Profiles")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showEditor) {
            if let editingProfile {
                NavigationStack {
                    GymProfileEditorView(profile: editingProfile) { saved in
                        gymProfiles.upsert(saved)
                        gymProfiles.selectProfile(saved.id)
                        showEditor = false
                    }
                }
            }
        }
    }
}

struct GymProfileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var profile: GymEquipmentProfile
    let onSave: (GymEquipmentProfile) -> Void

    var body: some View {
        Form {
            Section("Name") {
                TextField("Gym name", text: $profile.name)
            }

            Section("Default weight unit") {
                Picker("Unit", selection: $profile.defaultWeightUnit) {
                    ForEach(WeightUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                Text("Used as context for this gym. Exercise-specific overrides and history stay separate.")
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }

            Section("Notes") {
                TextField("Optional notes", text: $profile.notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Available equipment") {
                GymEquipmentPicker(selection: $profile.availableEquipment)
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    onSave(profile)
                    dismiss()
                }
                .disabled(profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
