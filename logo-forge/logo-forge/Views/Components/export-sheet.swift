import SwiftUI

// MARK: - Export Sheet
// Modal overlay - logo preview stays visible, always looking at your work

struct ExportSheet: View {
    let image: NSImage
    @Bindable var options: ExportOptions

    let onExport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("EXPORT")
                .font(LogoForgeTheme.body(12, weight: .medium))
                .foregroundStyle(LogoForgeTheme.textSecondary)
                .tracking(2)
                .padding(.top, 32)
                .padding(.bottom, 24)

            // Logo preview
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: 180)
                .padding(24)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LogoForgeTheme.surface)
                )
                .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
                .padding(.horizontal, 40)

            // Divider
            Rectangle()
                .fill(LogoForgeTheme.border)
                .frame(height: 1)
                .padding(.vertical, 28)
                .padding(.horizontal, 40)

            // Options
            HStack(alignment: .top, spacing: 48) {
                // Platforms
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("PLATFORMS")

                    ForEach(ExportBundle.allCases) { bundle in
                        BundleToggle(
                            bundle: bundle,
                            isSelected: options.selectedBundles.contains(bundle)
                        ) {
                            if options.selectedBundles.contains(bundle) {
                                options.selectedBundles.remove(bundle)
                            } else {
                                options.selectedBundles.insert(bundle)
                            }
                        }
                    }
                }

                // Enhancement options
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader("OPTIONS")

                    Text("Enhancement")
                        .font(LogoForgeTheme.body(13))
                        .foregroundStyle(LogoForgeTheme.textSecondary)

                    ForEach(UpscaleMode.allCases) { mode in
                        RadioOption(
                            label: mode.rawValue,
                            isSelected: options.upscaleMode == mode
                        ) {
                            options.upscaleMode = mode
                        }
                    }

                    Spacer().frame(height: 8)

                    CheckboxOption(
                        label: "Include dark variant",
                        isOn: $options.generateVariants
                    )
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // Footer
            VStack(spacing: 16) {
                Rectangle()
                    .fill(LogoForgeTheme.border)
                    .frame(height: 1)

                HStack {
                    Spacer()

                    if options.estimatedCost > 0 {
                        Text("$\(options.estimatedCost as NSDecimalNumber) estimated")
                            .font(LogoForgeTheme.body(13))
                            .foregroundStyle(LogoForgeTheme.textSecondary)
                    }

                    Spacer().frame(width: 24)

                    Button("Cancel", action: onCancel)
                        .buttonStyle(SecondaryButtonStyle())

                    Button(action: onExport) {
                        HStack(spacing: 6) {
                            Text("Export")
                            Image(systemName: "arrow.right")
                                .font(.system(size: 11, weight: .medium))
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 540, height: 560)
        .background(LogoForgeTheme.canvas)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(LogoForgeTheme.body(11, weight: .medium))
            .foregroundStyle(LogoForgeTheme.textSecondary)
            .tracking(1.5)
    }
}

// MARK: - Bundle Toggle

private struct BundleToggle: View {
    let bundle: ExportBundle
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Checkbox
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? LogoForgeTheme.paper : LogoForgeTheme.border, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? LogoForgeTheme.paper : .clear)
                    )
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LogoForgeTheme.canvas)
                            .opacity(isSelected ? 1 : 0)
                    )

                // Icon
                Image(systemName: bundle.iconName)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? LogoForgeTheme.textPrimary : LogoForgeTheme.textSecondary)
                    .frame(width: 20)

                // Label
                Text(bundle.displayName)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(isSelected ? LogoForgeTheme.textPrimary : LogoForgeTheme.textSecondary)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? LogoForgeTheme.hover : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Radio Option

struct RadioOption: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Radio circle
                Circle()
                    .stroke(isSelected ? LogoForgeTheme.paper : LogoForgeTheme.border, lineWidth: 1.5)
                    .background(
                        Circle()
                            .fill(isSelected ? LogoForgeTheme.paper : .clear)
                            .padding(4)
                    )
                    .frame(width: 16, height: 16)

                // Label
                Text(label)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(isSelected ? LogoForgeTheme.textPrimary : LogoForgeTheme.textSecondary)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? LogoForgeTheme.hover : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Checkbox Option

struct CheckboxOption: View {
    let label: String
    @Binding var isOn: Bool

    @State private var isHovered = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                // Checkbox
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isOn ? LogoForgeTheme.paper : LogoForgeTheme.border, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isOn ? LogoForgeTheme.paper : .clear)
                    )
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(LogoForgeTheme.canvas)
                            .opacity(isOn ? 1 : 0)
                    )

                // Label
                Text(label)
                    .font(LogoForgeTheme.body(13))
                    .foregroundStyle(isOn ? LogoForgeTheme.textPrimary : LogoForgeTheme.textSecondary)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? LogoForgeTheme.hover : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Preview

#Preview {
    ExportSheet(
        image: NSImage(systemSymbolName: "star.fill", accessibilityDescription: nil)!,
        options: ExportOptions(),
        onExport: {},
        onCancel: {}
    )
}
