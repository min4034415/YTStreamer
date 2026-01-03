// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "YTStreamer",
    platforms: [
        .macOS(.v12)
    ],
    targets: [
        .executableTarget(
            name: "YTStreamer",
            path: "YTStreamer",
            sources: [
                "App/AppDelegate.swift",
                "Models/Track.swift",
                "Models/History.swift",
                "Services/StreamManager.swift",
                "Services/YouTubeDownloader.swift",
                "Services/AudioConverter.swift",
                "Services/HTTPServer.swift",
                "Services/NetworkInfo.swift",
                "Utilities/ProcessRunner.swift",
                "Utilities/BundledTools.swift",
                "Views/MenuBarViewController.swift",
                "Views/MainWindowController.swift"
            ]
        )
    ]
)
