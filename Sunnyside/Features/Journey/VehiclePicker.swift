import SwiftUI

struct VehiclePicker: View {
    @Binding var selected: Vehicle
    var onChange: ((Vehicle) -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Vehicle.allCases) { vehicle in
                Button {
                    guard vehicle != selected else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                        selected = vehicle
                    }
                    onChange?(vehicle)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: vehicle.systemIcon)
                            .font(.system(.title3, weight: .semibold))
                        Text(vehicle.displayName)
                            .font(.system(.caption, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(selected == vehicle ? Color.appBackground : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 64)
                    .background(selected == vehicle ? Color.sunAmber : Color.appSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.fieldCorner, style: .continuous)
                            .strokeBorder(selected == vehicle ? Color.clear : Color.appBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(vehicle.displayName)
                .accessibilityAddTraits(selected == vehicle ? [.isSelected] : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selected)
    }
}
