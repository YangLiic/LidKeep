import SwiftUI

private enum UIStyle {
    static let cornerRadius: CGFloat = 7
    static var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

struct ActionButtonStyle: ButtonStyle {
    enum Kind { case apply, restore, uninstall }
    enum Size { case regular, main }
    let kind: Kind
    var size: Size = .regular
    @Environment(\.isEnabled) private var isEnabled

    private var foreground: Color {
        guard isEnabled else { return .secondary }
        switch kind {
        case .apply: return .white
        case .restore: return .primary
        case .uninstall: return .red
        }
    }
    private var background: Color {
        guard isEnabled else { return .secondary.opacity(0.12) }
        switch kind {
        case .apply: return .blue
        case .restore: return .secondary.opacity(0.08)
        case .uninstall: return .red.opacity(0.08)
        }
    }
    private var border: Color {
        guard isEnabled else { return .secondary.opacity(0.16) }
        switch kind {
        case .apply: return .blue
        case .restore: return .secondary.opacity(0.4)
        case .uninstall: return .red.opacity(0.65)
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size == .main ? 14 : 13, weight: size == .main ? .semibold : .medium))
            .foregroundStyle(foreground)
            .padding(.horizontal, 12)
            .padding(.vertical, size == .main ? 10 : 8)
            .background(background.opacity(configuration.isPressed ? 0.75 : 1), in: UIStyle.shape)
            .overlay(UIStyle.shape.strokeBorder(border, lineWidth: 1))
            .contentShape(UIStyle.shape)
    }
}

private struct SettingsPanelStyle: ViewModifier {
    let inset: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.55), in: UIStyle.shape)
            .overlay(UIStyle.shape.strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
    }
}

extension View {
    func lidKeepPanel(inset: CGFloat = 14) -> some View {
        modifier(SettingsPanelStyle(inset: inset))
    }
}
