import Foundation
import TerminalServiceInterface

// MARK: - DefaultTerminalService

public final class DefaultTerminalService: TerminalService {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  /// Synchronously runs this command and returns its result
  /// This is the most full-featured shell command, all others
  /// call through to this one with certain arguments with defaults
  @discardableResult
  public func runTerminal(
    _ command: String,
    input: String? = nil,
    quiet: Bool = false,
    cwd: String? = nil
  ) async throws -> TerminalResult {
    // Log command if desired

    // Command being run
    let process = Process()
    process.launchPath = "/bin/zsh"
    process.arguments = ["-c"] + [command]

    // Working directory
    if let cwd {
      process.currentDirectoryPath = cwd
    }

    // Input/output
    let inputPipe = Pipe()
    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    return try await withCheckedThrowingContinuation { continuation in
      var outputData: Data?
      var errorData: Data?

      // Set up the termination handler before starting the process to ensure that it is called.
      process.terminationHandler = { process in
        let terminationStatus = process.terminationStatus

        let result = TerminalResult(
          exitCode: terminationStatus,
          output: outputData?.toString(),
          errorOutput: errorData?.toString()
        )

        continuation.resume(returning: result)
      }

      do {
        try process.run()
      } catch let error {
        continuation.resume(throwing: error)
        return
      }

      if let input {
        let inputData = Data(input.utf8)
        do {
          try inputPipe.fileHandleForWriting.write(contentsOf: inputData)
          try inputPipe.fileHandleForWriting.close()
        } catch let error {
          continuation.resume(throwing: error)
          return
        }
      }

      // Begin reading stdout before waiting for the process to terminate.
      // Otherwise it's possible for the two processes to deadlock, with the
      // child process waiting to print to stdout until there is a valid listener.
      do {
        outputData = try outputPipe.fileHandleForReading.readToEnd()
        errorData = try errorPipe.fileHandleForReading.readToEnd()
      } catch {
        continuation.resume(throwing: error)
        return
      }
    }
  }
}

// MARK: - Data

/// Extension on Data for String creation
extension Data {
  public func toString(stripWhitespace: Bool = true) -> String? {
    let rawString = String(data: self, encoding: .utf8)
    if stripWhitespace {
      return rawString?.trimmingCharacters(in: .whitespacesAndNewlines)
    } else {
      return rawString
    }
  }
}
