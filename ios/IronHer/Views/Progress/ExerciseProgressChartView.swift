import Charts
import SwiftUI

struct ExerciseProgressChartView: View {
    let series: ExerciseProgressSeries
    let exercise: Exercise
    let weightUnit: WeightUnit
    @Binding var selectedSessionId: UUID?

    private var selectedPoint: ExerciseProgressPoint? {
        guard let selectedSessionId else { return nil }
        return series.points.first { $0.sessionId == selectedSessionId }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selected = selectedPoint {
                selectedAnnotation(selected)
            } else if series.points.count == 1, let only = series.points.first {
                selectedAnnotation(only)
            }

            chart
                .frame(height: 220)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilityDescription)
        }
    }

    @ViewBuilder
    private var chart: some View {
        let points = series.points
        Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("Date", point.completedAt),
                    y: .value(series.metric.chartAccessibilityNoun, point.metricValue)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(IronHerTheme.accent)

                PointMark(
                    x: .value("Date", point.completedAt),
                    y: .value(series.metric.chartAccessibilityNoun, point.metricValue)
                )
                .symbolSize(point.sessionId == selectedSessionId || points.count == 1 ? 64 : 36)
                .foregroundStyle(IronHerTheme.accent)
            }

            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.completedAt))
                    .foregroundStyle(IronHerTheme.separator)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartYScale(domain: yDomain(for: points))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: min(4, max(points.count, 1)))) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(IronHerTheme.separator.opacity(0.45))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.abbreviated).day())
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(IronHerTheme.separator.opacity(0.45))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(axisLabel(for: number))
                            .font(SheLiftsFont.caption)
                            .foregroundStyle(IronHerTheme.secondaryText)
                    }
                }
            }
        }
        .chartXSelection(value: selectionBinding)
    }

    private var selectionBinding: Binding<Date?> {
        Binding(
            get: {
                selectedPoint?.completedAt
            },
            set: { newDate in
                guard let newDate else {
                    selectedSessionId = nil
                    return
                }
                selectedSessionId = nearestPoint(to: newDate)?.sessionId
            }
        )
    }

    private func nearestPoint(to date: Date) -> ExerciseProgressPoint? {
        series.points.min { a, b in
            abs(a.completedAt.timeIntervalSince(date)) < abs(b.completedAt.timeIntervalSince(date))
        }
    }

    private func yDomain(for points: [ExerciseProgressPoint]) -> ClosedRange<Double> {
        ExerciseProgressSeriesBuilder.yAxisDomain(values: points.map(\.metricValue)) ?? 0...1
    }

    private func axisLabel(for value: Double) -> String {
        switch series.metric {
        case .estimatedStrength:
            return WeightFormatter.formatNumber(kg: value, unit: weightUnit)
        case .bestReps:
            return "\(Int(value.rounded()))"
        case .longestDuration:
            return ExerciseProgressSeriesBuilder.formatDurationClock(seconds: Int(value.rounded()))
        }
    }

    private func selectedAnnotation(_ point: ExerciseProgressPoint) -> some View {
        let detail = ExerciseProgressSeriesBuilder.formatPointDetail(
            point: point,
            metric: series.metric,
            exercise: exercise,
            weightUnit: weightUnit
        )

        return VStack(alignment: .leading, spacing: 4) {
            Text(detail.dateLine)
                .font(SheLiftsFont.caption)
                .foregroundStyle(IronHerTheme.secondaryText)
            Text(detail.primaryLine)
                .font(SheLiftsFont.bodyMedium)
                .foregroundStyle(IronHerTheme.primaryText)
            if let secondary = detail.secondaryLine {
                Text(secondary)
                    .font(SheLiftsFont.caption)
                    .foregroundStyle(IronHerTheme.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var accessibilityDescription: String {
        guard !series.points.isEmpty else {
            return "No progress data yet"
        }
        let noun = series.metric.chartAccessibilityNoun
        if series.points.count == 1, let only = series.points.first {
            let value = ExerciseProgressSeriesBuilder.formatMetricValue(
                only.metricValue,
                metric: series.metric,
                weightUnit: weightUnit
            )
            return "\(noun) chart with one session at \(value)"
        }
        guard let first = series.points.first, let last = series.points.last else {
            return "\(noun) chart"
        }
        let start = ExerciseProgressSeriesBuilder.formatMetricValue(
            first.metricValue,
            metric: series.metric,
            weightUnit: weightUnit
        )
        let end = ExerciseProgressSeriesBuilder.formatMetricValue(
            last.metricValue,
            metric: series.metric,
            weightUnit: weightUnit
        )
        return "\(noun) chart with \(series.points.count) sessions, from \(start) to \(end)"
    }
}
