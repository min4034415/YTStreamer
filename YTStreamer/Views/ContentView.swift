import SwiftUI

struct ContentView: View {
    @StateObject private var streamManager = StreamManager.shared
    @StateObject private var trackQueue = TrackQueue.shared
    @State private var urlInput = ""
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - Queue
            VStack(alignment: .leading) {
                Text("Queue (\(trackQueue.tracks.count))")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                if trackQueue.tracks.isEmpty {
                    Text("No tracks in queue")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    List(trackQueue.tracks) { track in
                        HStack {
                            if track.id == streamManager.currentTrack?.id {
                                Image(systemName: "play.fill")
                                    .foregroundColor(.blue)
                            }
                            VStack(alignment: .leading) {
                                Text(track.title)
                                    .font(.body)
                                    .lineLimit(1)
                                    .fontWeight(track.id == streamManager.currentTrack?.id ? .bold : .regular)
                                Text(track.artist ?? "Unknown Artist")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Spacer()
            }
            .frame(minWidth: 200)
        } detail: {
            // Main Content
            VStack(spacing: 20) {
                Spacer()
                
                // Thumbnail
                if let track = streamManager.currentTrack,
                   let thumbnailURL = track.thumbnailURL,
                   let url = URL(string: thumbnailURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } placeholder: {
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 200, height: 200)
                    .cornerRadius(12)
                } else {
                    Image(systemName: "music.note")
                        .font(.system(size: 80))
                        .foregroundColor(.secondary)
                        .frame(width: 200, height: 200)
                }
                
                // Track Info
                Text(streamManager.currentTrack?.title ?? "No track playing")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(streamManager.currentTrack?.artist ?? "")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                // Status
                if streamManager.status == .downloading {
                    ProgressView(value: streamManager.downloadProgress)
                        .frame(width: 300)
                    Text("Downloading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if streamManager.status == .error {
                    Text(streamManager.status.rawValue)
                        .font(.caption)
                        .foregroundColor(.red)
                    if let error = streamManager.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    Text(streamManager.status.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Stream URL Box - Always visible
                VStack(spacing: 8) {
                    Text("Stream URL")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    if let streamURL = streamManager.streamURL {
                        HStack {
                            Text(streamURL)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.blue)
                                .textSelection(.enabled)
                            
                            Button("Copy") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(streamURL, forType: .string)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        
                        Text("Open this URL on any device in your network")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not streaming yet")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        Text("Add a YouTube URL below to start streaming")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
                
                // URL Input
                HStack {
                    TextField("Paste YouTube URL...", text: $urlInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 300)
                    
                    Button("Add & Play") {
                        guard !urlInput.isEmpty else { return }
                        streamManager.addAndPlay(url: urlInput)
                        urlInput = ""
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    ContentView()
}
