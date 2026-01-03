import Foundation

/// Runs shell commands and captures output
class ProcessRunner {

    struct Result {
        let output: String
        let error: String
        let exitCode: Int32
    }

    /// Run a command synchronously
    static func run(_ command: String, arguments: [String] = [], workingDirectory: String? = nil) -> Result {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let workDir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        }

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return Result(output: "", error: error.localizedDescription, exitCode: -1)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()

        let output = String(data: outputData, encoding: .utf8) ?? ""
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

        return Result(output: output, error: errorOutput, exitCode: process.terminationStatus)
    }

    /// Run a command asynchronously with progress callback
    static func runAsync(
        _ command: String,
        arguments: [String] = [],
        workingDirectory: String? = nil,
        onOutput: @escaping (String) -> Void,
        onError: @escaping (String) -> Void,
        completion: @escaping (Int32) -> Void
    ) -> Process {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: command)
        process.arguments = arguments
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        if let workDir = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: workDir)
        }

        // Handle output
        outputPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async {
                    onOutput(str)
                }
            }
        }

        // Handle error
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                DispatchQueue.main.async {
                    onError(str)
                }
            }
        }

        process.terminationHandler = { process in
            DispatchQueue.main.async {
                completion(process.terminationStatus)
            }
        }

        do {
            try process.run()
        } catch {
            onError(error.localizedDescription)
            completion(-1)
        }

        return process
    }
}
