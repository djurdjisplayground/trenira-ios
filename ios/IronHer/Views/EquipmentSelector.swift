import SwiftUI

struct EquipmentSelector: View {
    @Binding var choice: TodayEquipmentChoice

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What would you like to use today?")
                .font(TreniraType.displayTitle)
                .foregroundStyle(TreniraColor.label)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            ForEach(MovementEquipment.allCases) { item in
                EquipmentOptionCard(
                    title: item.title,
                    detail: item.summary,
                    isSelected: choice == .focused(item)
                ) {
                    choice = .focused(item)
                }
            }
            EquipmentOptionCard(
                title: "Surprise me",
                detail: "Uses the equipment you have marked as available.",
                isSelected: choice == .surprise
            ) {
                choice = .surprise
            }
        }
    }
}

struct EquipmentOptionCard: View {
    var title: String
    var detail: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(.title3, design: .serif))
                        .foregroundStyle(TreniraColor.label)
                    Text(detail)
                        .font(TreniraType.body)
                        .foregroundStyle(TreniraColor.labelSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 8)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? TreniraColor.plum : TreniraColor.orchid)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TreniraColor.lavender : TreniraColor.elevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isSelected ? TreniraColor.plum : TreniraColor.mauve, lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
