import Foundation

// MARK: - TerminalResult

/// The result of a shell command invocation
public struct TerminalResult: Equatable {
  public let exitCode: Int32
  public let output: String?
  public let errorOutput: String?

  public init(exitCode: Int32, output: String? = nil, errorOutput: String? = nil) {
    self.exitCode = exitCode
    self.output = output
    self.errorOutput = errorOutput
  }
}

// MARK: - TerminalService

/// A single command line invocation
public protocol TerminalService {

  // MARK: Public
  /// Runs this command and returns its result
  /// This is the most full-featured shell command, all others
  /// call through to this one with certain arguments with defaults
  @discardableResult
  func runTerminal(
    _ command: String,
    input: String?,
    quiet: Bool,
    cwd: String?
  ) async throws -> TerminalResult
}

extension TerminalService {

  /// Simple command to run a command and return STDOUT
  public func output(_ command: String, cwd: String? = nil, quiet: Bool = false) async throws -> String? {
    let result = try await runTerminal(command, cwd: cwd, quiet: quiet)
    return result.output
  }

  /// Runs this command and returns its result
  /// This is the most full-featured shell command, all others
  /// call through to this one with certain arguments with defaults
  @discardableResult
  public func runTerminal(
    _ command: String,
    input: String? = nil,
    cwd: String? = nil,
    quiet: Bool = false
  ) async throws -> TerminalResult {
    try await runTerminal(command, input: input, quiet: quiet, cwd: cwd)
  }
}


// MARK: - TerminalServiceProviding

/// A protocol that defines a provider for terminal service instances.
/// 
/// Types conforming to this protocol must provide access to a `TerminalService` instance,
/// enabling dependency injection and testability for components that require terminal functionality.
public protocol TerminalServiceProviding {

  /// The terminal service instance provided by this conforming type.
  /// 
  /// This property gives access to terminal operations such as executing commands,
  /// managing terminal sessions, and handling terminal output.
  var terminalService: TerminalService { get }
}
