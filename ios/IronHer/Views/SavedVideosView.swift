import SwiftUI

struct SavedVideosView: View {
    @Environment(\.openURL) private var openURL
    var ownerId: String
    @State private var videos: [SavedVideo] = []
    @State private var showAdd = false

    var body: some View {
        Group {
            if videos.isEmpty {
                ContentUnavailableView(
                    "No videos yet",
                    systemImage: "play.rectangle",
                    description: Text("Save a video you already like. trenira opens it outside the app and does not guess its length.")
                )
            } else {
                List(videos) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title)
                            .font(TreniraType.bodyMedium)
                            .foregroundStyle(TreniraColor.label)
                        Text(video.durationMinutes.map { "\($0) minutes, as you entered" } ?? "Length not saved")
                            .font(TreniraType.caption)
                            .foregroundStyle(TreniraColor.labelSecondary)
                        if let url = video.url {
                            Button("Open") { openURL(url) }
                        }
                        NavigationLink("Record that I did this") {
                            RecordSavedVideo(video: video, ownerId: ownerId)
                        }
                    }
                    .listRowBackground(TreniraColor.elevated)
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(TreniraColor.canvas)
        .navigationTitle("Videos")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add") { showAdd = true }
            }
        }
        .sheet(isPresented: $showAdd, onDismiss: reload) {
            AddSavedVideoView(ownerId: ownerId) { showAdd = false }
        }
        .onAppear(perform: reload)
    }

    private func reload() {
        videos = SavedVideoStore.load(ownerId: ownerId)
    }
}

private struct RecordSavedVideo: View {
    var video: SavedVideo
    var ownerId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        MovementCompletionView(
            title: video.title,
            kind: .externalVideo,
            plannedMinutes: video.durationMinutes,
            initialActualMinutes: video.durationMinutes ?? 10,
            videoId: video.id,
            ownerId: ownerId,
            onSaved: { dismiss() }
        )
    }
}

struct AddSavedVideoView: View {
    var ownerId: String
    var onSaved: () -> Void

    @State private var title = ""
    @State private var link = ""
    @State private var knowsDuration = false
    @State private var duration = 10
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: TreniraSpace.section) {
                    TextField("Title", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("YouTube link", text: $link)
                        .textFieldStyle(.roundedBorder)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Toggle("I know the length", isOn: $knowsDuration)
                        .tint(TreniraColor.action)
                    if knowsDuration {
                        Stepper(value: $duration, in: 1...180) {
                            Text("\(duration) minutes")
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(TreniraType.caption)
                            .foregroundStyle(TreniraColor.label)
                    }
                    Button("Save video") { save() }
                        .buttonStyle(TreniraPrimaryButtonStyle())
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || link.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(TreniraSpace.screen)
            }
            .background(TreniraColor.canvas)
            .navigationTitle("Add video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: onSaved)
                }
            }
        }
    }

    private func save() {
        guard let url = YouTubeLink.validatedURL(from: link) else {
            errorMessage = "That link isn't a YouTube address trenira can open."
            return
        }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        SavedVideoStore.add(
            SavedVideo(
                id: UUID(),
                title: trimmed,
                urlString: url.absoluteString,
                durationMinutes: knowsDuration ? duration : nil,
                savedAt: .now,
                ownerId: ownerId
            )
        )
        onSaved()
    }
}
