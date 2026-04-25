import Foundation

/// Tiny abstraction over `Foundation.Process` so `DiagnosticExporter`
/// can be exercised in unit tests with a recorded-args mock without
/// actually spawning `/usr/bin/ditto`. Production wire is
/// `RealProcessRunner`.
protocol ProcessRunner: Sendable {
    func run(executable: URL, arguments: [String]) async throws -> ProcessResult
}

struct ProcessResult: Sendable, Equatable {
    let exitStatus: Int32
    let stdout: Data
    let stderr: Data
}

struct RealProcessRunner: ProcessRunner {
    func run(executable: URL, arguments: [String]) async throws -> ProcessResult {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ProcessResult, Error>) in
            do {
                let process = Process()
                process.executableURL = executable
                process.arguments = arguments
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.terminationHandler = { proc in
                    let stdout = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderr = errPipe.fileHandleForReading.readDataToEndOfFile()
                    cont.resume(returning: ProcessResult(
                        exitStatus: proc.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    ))
                }
                try process.run()
            } catch {
                cont.resume(throwing: error)
            }
        }
    }
}
