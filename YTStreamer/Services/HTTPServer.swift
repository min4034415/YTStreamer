import Foundation
import Network

/// Simple HTTP server to serve audio files
class HTTPServer {

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var filePath: String?
    private(set) var isRunning = false
    private(set) var port: UInt16 = 8000

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

            // Check if it's a GET request for our file
            if request.hasPrefix("GET") {
                self.sendFile(over: connection)
            } else {
                self.send404(over: connection)
            }
        }
    }

    private func sendFile(over connection: NWConnection) {
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
