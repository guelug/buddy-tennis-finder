import SwiftUI
import WidgetKit
import ActivityKit

private struct DailyStyleEntry: TimelineEntry {
    let date: Date
    let configuration: StyleCompanionConfigurationSnapshot
    let recommendation: DailyStyleRecommendationSnapshot?
}

private struct DailyStyleProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyStyleEntry {
        DailyStyleEntry(
            date: Date(),
            configuration: .default,
            recommendation: previewRecommendation
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyStyleEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyStyleEntry>) -> Void) {
        let entry = loadEntry()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 60, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadEntry() -> DailyStyleEntry {
        DailyStyleEntry(
            date: Date(),
            configuration: SharedStyleCompanionStore.loadConfiguration(),
            recommendation: SharedStyleCompanionStore.loadRecommendation()
        )
    }

    private var previewRecommendation: DailyStyleRecommendationSnapshot {
        DailyStyleRecommendationSnapshot(
            generatedAt: Date(),
            headline: "Look para hoy",
            eventTitle: "Client meeting",
            contextLine: "Hoy tienes una reunión importante y he priorizado un look pulido.",
            outfitFormula: "Base pulida, blazer ligero y un zapato que mantenga presencia sin rigidez.",
            colorDirection: "Neutros refinados con un acento suave favorecedor.",
            accessoryNote: "Accesorios discretos y bolso estructurado.",
            closetHighlightNames: ["Blazer camel", "Pantalón recto navy"],
            moodTags: ["Trabajo", "Pulido", "Versátil"],
            spokenSummary: "Look para hoy. Hoy tienes una reunión importante y he priorizado un look pulido."
        )
    }
}

struct DailyStyleRecommendationWidget: Widget {
    let kind = "DailyStyleRecommendationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyStyleProvider()) { entry in
            DailyStyleRecommendationWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Style")
        .description("See today's Personal Shooper recommendation at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct DailyStyleRecommendationWidgetView: View {
    let entry: DailyStyleEntry
    @Environment(\.widgetFamily) private var family

    private var isSpanish: Bool {
        entry.configuration.preferredLanguageRaw == "es"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.95, blue: 0.90),
                    Color(red: 0.95, green: 0.89, blue: 0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                header

                if !entry.configuration.widgetRecommendationsEnabled {
                    disabledState
                } else if let recommendation = entry.recommendation {
                    recommendationState(recommendation)
                } else {
                    emptyState
                }
            }
            .padding(family == .systemSmall ? 14 : 16)
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("PERSONAL SHOPPER")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(isSpanish ? "Look diario" : "Daily Style")
                    .font(.system(size: family == .systemSmall ? 16 : 18, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.84))
            }

            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.7))
        }
    }

    private var disabledState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSpanish ? "Widget desactivado" : "Widget disabled")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(isSpanish ? "Activa los widgets diarios en ajustes para ver aquí la recomendación de hoy." : "Enable daily widgets in settings to mirror today's recommendation here.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isSpanish ? "Sin recomendación todavía" : "No recommendation yet")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Text(isSpanish ? "Abre la app para generar la guía de outfit de hoy." : "Open the app to generate today's outfit guidance.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func recommendationState(_ recommendation: DailyStyleRecommendationSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recommendation.headline)
                .font(.system(size: family == .systemSmall ? 15 : 17, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.9))
                .lineLimit(family == .systemSmall ? 2 : 1)

            Text(family == .systemSmall ? recommendation.contextLine : recommendation.outfitFormula)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Color.black.opacity(0.68))
                .lineLimit(family == .systemSmall ? 3 : 2)

            if family == .systemMedium && !recommendation.moodTags.isEmpty {
                HStack(spacing: 6) {
                    ForEach(Array(recommendation.moodTags.prefix(3)), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.65))
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Daily Outfit Live Activity (Dynamic Island)

struct DailyOutfitLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DailyOutfitActivityAttributes.self) { context in
            DailyOutfitLockScreenView(state: context.state)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.timeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(context.state.headline)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.state.outfitFormula)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        if !context.state.moodTags.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(context.state.moodTags.prefix(3), id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(.white.opacity(0.16), in: Capsule())
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.timeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } minimal: {
                Image(systemName: "sparkles")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct DailyOutfitLockScreenView: View {
    let state: DailyOutfitActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.headline)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(state.outfitFormula)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding()
    }
}

@main
struct PersonalShooperWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DailyStyleRecommendationWidget()
        DailyOutfitLiveActivity()
    }
}
