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
    // Palette
    static let ink = Color(hex: 0x14171C)
    static let slate = Color(hex: 0x5B6472)
    static let mist = Color(hex: 0xF3F5F8)
    static let accent = Color(hex: 0x2F6BFF)
    static let urgent = Color(hex: 0xFF6A2C)

    // Semantic
    static let pageBackground = Color(light: mist, dark: Color(hex: 0x0E1014))
    static let surface = Color(light: .white, dark: Color(hex: 0x1B1F26))
    static let primaryText = Color(light: ink, dark: Color(hex: 0xF2F4F8))
    static let secondaryText = Color(light: slate, dark: Color(hex: 0x9BA5B4))
    static let separator = Color(light: Color(hex: 0xE3E7ED), dark: Color(hex: 0x2B313A))

    /// Stable per-line tint so the same line always looks the same in app and widget.
    static func lineTint(for lineName: String) -> Color {
        let palette = [
            Color(hex: 0x2F6BFF), Color(hex: 0x00A37A), Color(hex: 0xE0553C),
            Color(hex: 0x7B5BE0), Color(hex: 0xC8952B), Color(hex: 0x0E8FBF),
            Color(hex: 0xD2478E), Color(hex: 0x4A8C2A)
        ]
        let hash = lineName.unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 100_003 }
        return palette[hash % palette.count]
    }
}

// MARK: - Metrics

enum AppMetrics {
    static let spacingXS: CGFloat = 4
    static let spacingS: CGFloat = 8
    static let spacingM: CGFloat = 12
    static let spacingL: CGFloat = 16
    static let spacingXL: CGFloat = 24

    static let cardRadius: CGFloat = 20
    static let badgeRadius: CGFloat = 7

    static let rowMinHeight: CGFloat = 56
    static let compactRowMinHeight: CGFloat = 40
    static let tapTarget: CGFloat = 44
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
                .fill(AppTheme.ink)

            VStack(alignment: .leading, spacing: 3) {
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: 12, height: 3)
                Capsule()
                    .fill(AppTheme.accent)
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
            .font(compact ? .system(size: 10, weight: .bold) : .caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, compact ? 5 : 8)
            .padding(.vertical, compact ? 2 : 4)
            .background(
                Capsule().fill(AppTheme.lineTint(for: lineName))
            )
    }
}

/// Remaining minutes until the next departure. `nil` means service is over for today.
struct ArrivalCountdown: View {
    let minutes: Int?
    var compact: Bool = false

    var body: some View {
        switch minutes {
        case nil:
            Text("今日结束")
                .font(compact ? .caption2 : .subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .lineLimit(1)
        case 0:
            Text("即将到站")
                .font(compact ? .caption.weight(.bold) : .subheadline.weight(.bold))
                .foregroundStyle(AppTheme.urgent)
                .lineLimit(1)
        case let value?:
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(value)")
                    .font((compact ? Font.title3 : Font.title2).weight(.bold).monospacedDigit())
                    .fontDesign(.rounded)
                Text("分")
                    .font(compact ? .system(size: 9, weight: .semibold) : .caption.weight(.semibold))
            }
            .foregroundStyle(AppTheme.primaryText)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(value) 分钟")
        }
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

            VStack(alignment: .leading, spacing: AppMetrics.spacingXS) {
                if showsLineBadge {
                    HStack(spacing: AppMetrics.spacingXS) {
                        LineBadge(lineName: lineName, compact: compact)
                        favoriteMark
                    }
                }

                HStack(spacing: AppMetrics.spacingXS) {
                    Text("往 \(directionName)")
                        .font(compact ? .caption.weight(.semibold) : .body.weight(.semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                    if !showsLineBadge {
                        favoriteMark
                    }
                }
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
                .foregroundStyle(AppTheme.urgent)
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
}

enum StorageKey {
    static let nearestStation = "nearestStation"
    static let latitude = "latitude"
    static let longitude = "longitude"
    static let lastUpdateTime = "lastUpdateTime"
    static let directionArrivals = "directionArrivals"
    static let favoriteDirections = "favoriteDirections"
}
