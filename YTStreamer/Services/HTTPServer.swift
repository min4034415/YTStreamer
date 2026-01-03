import Foundation
import Network

/// Simple HTTP server to serve audio files
class HTTPServer {

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var filePath: String?
    private(set) var isRunning = false
    private(set) var port: UInt16 = 8000
    
    // Track metadata for web player
    var trackTitle: String = "No track"
    var trackArtist: String = ""
    var thumbnailURL: String?
    
    // Remote control callbacks
    var onSkip: (() -> Void)?
    var onStop: (() -> Void)?
    
    // Active stream listeners
    private var streamListeners: [NWConnection] = []
    
    // Cached header (ID3 tags) for the current track
    var currentHeader: Data?

    /// Broadcast audio data to all connected listeners
    func broadcast(_ data: Data) {
        // Filter out cancelled/failed connections
        streamListeners = streamListeners.filter { $0.state != .cancelled && $0.state != .failed(.posix(.ECONNABORTED)) }
        
        for listener in streamListeners {
            listener.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("⚠️ Send error: \(error)")
                    listener.cancel()
                }
            })
        }
    }

    /// Start the HTTP server
    func start(servingFile path: String, port: UInt16 = 8000, completion: @escaping (Result<Void, Error>) -> Void) {
        self.filePath = path
        
        // Try ports 8000-8010
        tryStart(path: path, port: port, maxAttempts: 10, completion: completion)
    }
    
    private func tryStart(path: String, port: UInt16, maxAttempts: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        self.port = port
        
        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            listener = try NWListener(using: parameters, on: NWEndpoint.Port(rawValue: port)!)

            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isRunning = true
                    print("🌐 Server started on port \(port)")
                    DispatchQueue.main.async {
                        completion(.success(()))
                    }
                case .failed(let error):
                    self?.isRunning = false
                    self?.listener?.cancel()
                    self?.listener = nil
                    
                    // Try next port if address in use
                    if maxAttempts > 1 {
                        print("🌐 Port \(port) in use, trying \(port + 1)...")
                        self?.tryStart(path: path, port: port + 1, maxAttempts: maxAttempts - 1, completion: completion)
                    } else {
                        DispatchQueue.main.async {
                            completion(.failure(error))
                        }
                    }
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleConnection(connection)
            }

            listener?.start(queue: .global(qos: .userInitiated))

        } catch {
            if maxAttempts > 1 {
                tryStart(path: path, port: port + 1, maxAttempts: maxAttempts - 1, completion: completion)
            } else {
                completion(.failure(error))
            }
        }
    }

    /// Stop the HTTP server
    func stop() {
        listener?.cancel()
        listener = nil
        connections.forEach { $0.cancel() }
        connections.removeAll()
        isRunning = false
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)

        connection.start(queue: .global(qos: .userInitiated))

        // Receive HTTP request
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            guard let self = self, let data = data, error == nil else {
                connection.cancel()
                return
            }

            let request = String(data: data, encoding: .utf8) ?? ""
            
            // Parse request path
            if request.contains("GET /stream.mp3") || request.contains("GET /audio") {
                self.handleStreamRequest(over: connection)
            } else if request.contains("GET / ") || request.contains("GET /index") {
                self.sendPlayerPage(over: connection)
            } else if request.contains("GET /api/skip") {
                print("🌐 API Skip requested")
                DispatchQueue.main.async { self.onSkip?() }
                self.sendOK(over: connection)
            } else if request.contains("GET /api/stop") {
                print("🌐 API Stop requested")
                DispatchQueue.main.async { self.onStop?() }
                self.sendOK(over: connection)
            } else if request.hasPrefix("GET") {
                // Default to player page
                self.sendPlayerPage(over: connection)
            } else {
                self.send404(over: connection)
            }
        }
    }
    


    private func handleStreamRequest(over connection: NWConnection) {
        print("🎧 New listener connected!")
        
        // Send HTTP headers for continuous stream
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: audio/mpeg\r
        Connection: keep-alive\r
        Cache-Control: no-cache\r
        icy-name: YT Streamer\r
        \r
        
        """
        
        connection.send(content: Data(headers.utf8), completion: .contentProcessed { [weak self] error in
            if error == nil {
                // Send current ID3 header if available, so client gets metadata immediately
                if let header = self?.currentHeader {
                    print("📡 Sending cached ID3 header to new listener")
                    connection.send(content: header, completion: .contentProcessed { _ in
                         // Add to active listeners to receive broadcast data
                         self?.streamListeners.append(connection)
                    })
                } else {
                     // Add to active listeners directly
                     self?.streamListeners.append(connection)
                }
            } else {
                connection.cancel()
            }
        })
    }
    
    private func sendPlayerPage(over connection: NWConnection) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(trackTitle) - YT Streamer</title>
            <style>
                body {
                    font-family: -apple-system, Arial, sans-serif;
                    background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
                    color: white;
                    margin: 0;
                    padding: 20px;
                    min-height: 100vh;
                    display: flex;
                    flex-direction: column;
                    align-items: center;
                    justify-content: center;
                }
                .container {
                    text-align: center;
                    max-width: 400px;
                    background: rgba(255, 255, 255, 0.05);
                    padding: 30px;
                    border-radius: 20px;
                    backdrop-filter: blur(10px);
                }
                .thumbnail {
                    width: 250px;
                    height: 250px;
                    object-fit: cover;
                    border-radius: 12px;
                    box-shadow: 0 8px 32px rgba(0,0,0,0.4);
                    margin-bottom: 20px;
                }
                .title {
                    font-size: 1.2em;
                    font-weight: bold;
                    margin: 10px 0;
                }
                .artist {
                    font-size: 0.9em;
                    color: #aaa;
                    margin-bottom: 25px;
                }
                .controls {
                    display: flex;
                    gap: 15px;
                    justify-content: center;
                    margin-bottom: 20px;
                }
                button {
                    background: rgba(255, 255, 255, 0.1);
                    border: 1px solid rgba(255, 255, 255, 0.2);
                    color: white;
                    padding: 10px 20px;
                    border-radius: 8px;
                    cursor: pointer;
                    font-size: 1em;
                    transition: all 0.2s;
                }
                button:hover {
                    background: rgba(255, 255, 255, 0.2);
                }
                button.skip {
                    background: #007AFF;
                    border: none;
                }
                button.stop {
                    color: #ff453a;
                }
                .footer {
                    margin-top: 20px;
                    font-size: 0.7em;
                    color: #666;
                }
                audio {
                    width: 100%;
                    margin-top: 15px;
                    opacity: 0.8;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <img class="thumbnail" src="\(thumbnailURL ?? "")" onerror="this.style.display='none'">
                <div class="title">\(trackTitle)</div>
                <div class="artist">\(trackArtist)</div>
                
                <div class="controls">
                    <button class="stop" onclick="api('stop')">⏹ Stop</button>
                    <button class="skip" onclick="api('skip')">⏭ Skip</button>
                </div>

                <audio controls autoplay>
                    <source src="/stream.mp3" type="audio/mpeg">
                </audio>
                
                <div class="footer">YT Streamer • Refreshing in <span id="timer">30</span>s</div>
            </div>
            <script>
                function api(action) {
                    fetch('/api/' + action).then(() => {
                        if(action === 'skip') {
                            document.querySelector('.title').innerText = 'Skipping...';
                            setTimeout(() => location.reload(), 2000);
                        }
                    });
                }
                
                // Countdown timer
                let timeLeft = 30;
                setInterval(() => {
                    timeLeft--;
                    document.getElementById('timer').innerText = timeLeft;
                    if(timeLeft <= 0) location.reload();
                }, 1000);
            </script>
        </body>
        </html>
        """
        
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        
        """
        
        var response = Data(headers.utf8)
        response.append(Data(html.utf8))
        
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendAudioFile(over connection: NWConnection) {
        guard let path = filePath,
              let fileData = FileManager.default.contents(atPath: path) else {
            send404(over: connection)
            return
        }

        let contentLength = fileData.count
        let headers = """
        HTTP/1.1 200 OK\r
        Content-Type: audio/mpeg\r
        Content-Length: \(contentLength)\r
        Accept-Ranges: bytes\r
        Connection: close\r
        \r

        """

        var response = Data(headers.utf8)
        response.append(fileData)

        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendOK(over connection: NWConnection) {
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/plain\r
        Connection: close\r
        \r
        OK
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func send404(over connection: NWConnection) {
        let response = """
        HTTP/1.1 404 Not Found\r
        Content-Type: text/plain\r
        Connection: close\r
        \r
        Not Found
        """

        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

