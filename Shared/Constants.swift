//
//  Constants.swift
//  Approaching
//
//  Design system + shared constants used by both the app and the widget.
//

import Foundation
import SwiftUI

// MARK: - Colors

enum AppTheme {
    // Brand palette
    static let ink = Color(hex: 0x17313D)
    static let slate = Color(hex: 0x596B73)
    static let cream = Color(hex: 0xFAF3E9)
    static let accent = Color(hex: 0x1387C0)
    static let urgent = Color(hex: 0xF4520D)

    // Semantic colors
    static let pageBackground = Color(light: cream, dark: Color(hex: 0x0D2029))
    static let surface = Color(light: Color(hex: 0xFFFDF8), dark: Color(hex: 0x15313F))
    static let primaryText = Color(light: ink, dark: Color(hex: 0xFAF3E9))
    static let secondaryText = Color(light: slate, dark: Color(hex: 0xB9C8CC))
    static let separator = Color(light: Color(hex: 0xE3D7C5), dark: Color(hex: 0x2D4D59))
    static let onAccent = Color(hex: 0xFAF3E9)
    static let action = Color(light: Color(hex: 0x0D6B98), dark: Color(hex: 0x61C7F0))
    static let onAction = Color(light: cream, dark: Color(hex: 0x0D2029))
    static let stationSurface = action
    static let urgentText = Color(light: Color(hex: 0xB73700), dark: Color(hex: 0xFF9A76))
    static let urgentSurface = Color(light: Color(hex: 0xFCE2D6), dark: Color(hex: 0x582B1B))

    /// Official Beijing Metro identity colour (DB11/T 657.2-2015 Pantone equivalents).
    static func lineTint(for lineName: String) -> Color {
        guard let hex = lineHex(for: lineName) else { return action }
        return Color(hex: hex)
    }

    /// Readable text colour on top of a line colour; light lines need dark text.
    static func onLineTint(for lineName: String) -> Color {
        guard let hex = lineHex(for: lineName) else { return onAction }
        return luminance(of: hex) > 0.55 ? ink : cream
    }

    /// Lines whose identity colour cannot be derived from a number.
    private static let namedLineColors: [(token: String, hex: UInt32)] = [
        ("大兴机场", 0x0049A5),
        ("首都机场", 0xA192B2),
        ("S1", 0xA45A2A),
        ("昌平", 0xD986BA),
        ("燕房", 0xD86018),
        ("房山", 0xD86018),
        ("亦庄", 0xD0006F),
        ("西郊", 0xD22630)
    ]

    private static let numberedLineColors: [Int: UInt32] = [
        1: 0xA4343A, 2: 0x004B87, 3: 0xD90627, 4: 0x008C95, 5: 0xAA0061,
        6: 0xB58500, 7: 0xFFC56E, 8: 0x009B77, 9: 0x97D700, 10: 0x0092BC,
        11: 0xFF8674, 12: 0x9C4F01, 13: 0xF4DA40, 14: 0xCA9A8E, 15: 0x653279,
        16: 0x6BA539, 17: 0x00ABAB, 18: 0x685BC7, 19: 0xD3A3C9, 20: 0x666666,
        22: 0xF4C1CA, 28: 0x476205
    ]

    private static func lineHex(for lineName: String) -> UInt32? {
        // Named lines first: "S1线" would otherwise be read as line 1.
        if let match = namedLineColors.first(where: { lineName.contains($0.token) }) {
            return match.hex
        }
        let leadingDigits = String(lineName.prefix { $0.isNumber })
        guard let number = Int(leadingDigits) else { return nil }
        return numberedLineColors[number]
    }

    private static func luminance(of hex: UInt32) -> Double {
        let channels = [16, 8, 0].map { Double((hex >> UInt32($0)) & 0xFF) / 255 }
        let linear = channels.map { $0 <= 0.03928 ? $0 / 12.92 : pow(($0 + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
    }
}

// MARK: - Metrics

enum AppMetrics {
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24

    static let cardRadius: CGFloat = 16
    static let badgeRadius: CGFloat = 6

    static let rowMinHeight: CGFloat = 60
    static let compactRowMinHeight: CGFloat = 42
    static let tapTarget: CGFloat = 44
    static let readableWidth: CGFloat = 680
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    fileprivate init(light: Color, dark: Color) {
#if canImport(UIKit)
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
#else
        self = light
#endif
    }
}

// MARK: - Shared components

struct ApproachingMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppMetrics.badgeRadius, style: .continuous)
                .fill(AppTheme.accent)

            VStack(alignment: .leading, spacing: 3) {
                Capsule()
                    .fill(AppTheme.onAccent)
                    .frame(width: 12, height: 3)
                Capsule()
                    .fill(AppTheme.urgent)
                    .frame(height: 3)
            }
            .padding(6)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Compact line label with the line's own tint.
struct LineBadge: View {
    let lineName: String
    var compact: Bool = false

    var body: some View {
        Text(lineName)
            .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
            .foregroundStyle(AppTheme.onLineTint(for: lineName))
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, compact ? 6 : 9)
            .padding(.vertical, compact ? 3 : 5)
            .background(
                RoundedRectangle(cornerRadius: compact ? 4 : AppMetrics.badgeRadius, style: .continuous)
                    .fill(AppTheme.lineTint(for: lineName))
            )
    }
}

/// Circular line mark: the line number when available, otherwise a short name.
struct LineMark: View {
    let lineName: String
    var diameter: CGFloat = 22

    var body: some View {
        let label = Self.shortLabel(for: lineName)
        // Two CJK glyphs are much wider than two digits, so they need a smaller
        // size to keep clear of the circle's edge.
        let isNumeric = label.allSatisfy(\.isNumber)

        return Text(label)
            .font(.system(size: diameter * (isNumeric ? 0.5 : 0.32), weight: .bold, design: .rounded))
            .foregroundStyle(AppTheme.onLineTint(for: lineName))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, diameter * 0.08)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(AppTheme.lineTint(for: lineName)))
            .accessibilityLabel(lineName)
    }

    /// "13号线" -> "13", "昌平线" -> "昌平", "机场专线" -> "机场".
    static func shortLabel(for lineName: String) -> String {
        let digits = lineName.filter(\.isNumber)
        if !digits.isEmpty {
            return String(digits.prefix(2))
        }
        let trimmed = lineName.replacingOccurrences(of: "线", with: "")
        return String(trimmed.isEmpty ? lineName.prefix(2) : trimmed.prefix(2))
    }
}

/// Remaining minutes until the next departure. `nil` means service is over for today.
struct ArrivalCountdown: View {
    let minutes: Int?
    var compact: Bool = false

    var body: some View {
        Group {
            switch minutes {
            case nil:
                Text("今日结束")
                    .font(compact ? .caption2 : .subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            case 0:
                Text("即将到站")
                    .font(compact ? .caption2.weight(.bold) : .caption.weight(.bold))
                    .foregroundStyle(AppTheme.urgentText)
                    .lineLimit(1)
                    .padding(.horizontal, compact ? 5 : 8)
                    .padding(.vertical, compact ? 3 : 5)
                    .background(
                        RoundedRectangle(cornerRadius: AppMetrics.badgeRadius, style: .continuous)
                            .fill(AppTheme.urgentSurface)
                    )
                    .fixedSize(horizontal: true, vertical: false)
            case let value?:
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(value)")
                        .font((compact ? Font.title3 : Font.title2).weight(.bold).monospacedDigit())
                        .fontDesign(.rounded)
                    Text("分")
                        .font(compact ? .system(size: 9, weight: .semibold) : .caption.weight(.semibold))
                }
                .foregroundStyle(AppTheme.action)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(value) 分钟")
            }
        }
        .frame(minWidth: compact ? 46 : 64, alignment: .trailing)
    }
}

/// One direction of one line: line badge, destination, countdown, optional accessory.
struct ArrivalRow<Accessory: View>: View {
    let lineName: String
    let directionName: String
    let minutes: Int?
    var isFavorite: Bool = false
    var compact: Bool = false
    /// Set to `false` where the surrounding container already shows the line name.
    var showsLineBadge: Bool = true
    @ViewBuilder var accessory: () -> Accessory

    var body: some View {
        HStack(spacing: compact ? AppMetrics.spacingS : AppMetrics.spacingM) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(AppTheme.lineTint(for: lineName))
                .frame(width: 3, height: compact ? 26 : 34)

            HStack(spacing: AppMetrics.spacingXS) {
                if showsLineBadge {
                    LineBadge(lineName: lineName, compact: compact)
                }

                Text("往 \(directionName)")
                    .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                favoriteMark
            }

            Spacer(minLength: AppMetrics.spacingXS)

            ArrivalCountdown(minutes: minutes, compact: compact)

            accessory()
        }
        .frame(minHeight: compact ? AppMetrics.compactRowMinHeight : AppMetrics.rowMinHeight)
    }

    @ViewBuilder
    private var favoriteMark: some View {
        if isFavorite {
            Image(systemName: "heart.fill")
                .font(.system(size: compact ? 8 : 10, weight: .bold))
                .foregroundStyle(AppTheme.urgentText)
                .accessibilityHidden(true)
        }
    }
}

extension ArrivalRow where Accessory == EmptyView {
    init(lineName: String,
         directionName: String,
         minutes: Int?,
         isFavorite: Bool = false,
         compact: Bool = false,
         showsLineBadge: Bool = true) {
        self.init(
            lineName: lineName,
            directionName: directionName,
            minutes: minutes,
            isFavorite: isFavorite,
            compact: compact,
            showsLineBadge: showsLineBadge,
            accessory: { EmptyView() }
        )
    }
}

/// Standard card container used for every block in the app.
struct AppCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AppMetrics.spacingM) {
            content()
        }
        .padding(AppMetrics.spacingL)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppMetrics.cardRadius, style: .continuous)
                .stroke(AppTheme.separator, lineWidth: 1)
        )
    }
}

// MARK: - Identifiers

enum AppConstants {
    /// App Group identifier shared between the app and the widget extension.
    static let appGroupID = "group.wbr.Approaching"

    /// WidgetKit `kind` identifier.
    static let widgetKind = "ApproachingWidget"

    /// Number of directions shown in the widget.
    static let widgetDirectionCount = 2

    /// Beyond this distance the nearest station is assumed to be in another city,
    /// which the bundled timetable does not cover.
    static let supportedRadiusInMeters: Double = 50_000
}

enum StorageKey {
    static let nearestStation = "nearestStation"
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let lastUpdateTime = "lastUpdateTime"
    static let directionArrivals = "directionArrivals"
    static let favoriteDirections = "favoriteDirections"
}
