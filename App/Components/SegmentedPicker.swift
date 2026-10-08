import SwiftUI

/// Wraps a segmented `Picker`. The title is the VoiceOver label and is not shown.
struct SegmentedPicker<Value: Hashable>: View {
  @Environment(\.theme) private var theme
  private let title: String
  private let options: [Value]
  private let label: (Value) -> String
  private let selection: Binding<Value>

  init(
    _ title: String, selection: Binding<Value>, options: [Value], label: @escaping (Value) -> String
  ) {
    self.title = title
    self.selection = selection
    self.options = options
    self.label = label
  }

  var body: some View {
    Picker(title, selection: selection) {
      ForEach(options, id: \.self) { option in
        Text(label(option)).tag(option)
      }
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .tint(theme.primary)
    .accessibilityLabel(title)
  }
}

private struct SegmentedPreview: View {
  @Environment(\.theme) private var theme
  @State private var level = "Peek"

  var body: some View {
    SegmentedPicker("Assist level", selection: $level, options: ["Off", "Peek", "Coach"]) { $0 }
      .padding(Spacing.lg)
      .background(theme.bg)
  }
}

#Preview("Light") {
  SegmentedPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  SegmentedPreview().preferredColorScheme(.dark)
}
