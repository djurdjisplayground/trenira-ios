import SwiftUI

/// Progression rules (when/how) and long-term results — Track This Week lives on Home.
struct ProgressHubView: View {
    @Environment(LocalizationStore.self) private var l10n

    var body: some View {
        List {
            Section {
                NavigationLink(value: WorkoutRoute.myProgression) {
                    progressRow(
                        title: l10n.t(.progression_rules),
                        subtitle: l10n.t(.progression_rules_subtitle),
                        systemImage: "list.bullet.rectangle"
                    )
                }
            } footer: {
                Text(l10n.t(.progress_progression_footer))
                    .font(SheLiftsFont.caption)
            }

            Section {
                NavigationLink(value: WorkoutRoute.history) {
                    progressRow(
                        title: l10n.t(.progress_history),
                        subtitle: l10n.t(.progress_history_subtitle),
                        systemImage: "calendar"
                    )
                }
            } footer: {
                Text(l10n.t(.progress_history_section_footer))
                    .font(SheLiftsFont.caption)
            }
        }
        .listStyle(.insetGrouped)
        .background(IronHerTheme.groupedBackground)
        .navigationTitle(l10n.t(.progress_tab))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func progressRow(title: String, subtitle: String, systemImage: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(SheLiftsFont.bodyMedium)
                    .foregroundStyle(IronHerTheme.primaryText)
                Text(subtitle)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        } icon: {
            Image(systemName: systemImage)
        }
    }
}

#Preview {
    NavigationStack {
        ProgressHubView()
            .environment(LocalizationStore())
    }
}
