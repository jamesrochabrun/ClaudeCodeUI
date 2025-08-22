import Foundation

// MARK: - MockTerminalService

public final class MockTerminalService: TerminalService {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public struct UnexpectedCommandError: Error {
    public let command: String
    public init(command: String) {
      self.command = command
    }
  }

  public struct UncalledCommandError: Error {
    public init() { }
  }

  public var onRunTerminalCommand: ((String, String?, Bool, String?) throws -> TerminalResult)?

  public func runTerminal(_ command: String, input: String?, quiet: Bool, cwd: String?) async throws -> TerminalResult {
    try onRunTerminalCommand?(command, input, quiet, cwd) ?? .init(exitCode: 0, output: nil, errorOutput: nil)
  }
}

extension MockTerminalService {
  /// Returns the result of the block, ensuring that all the provided commands are called in the expected order, and that no other command is called during the execution.
  public func ensureAllInvocationsAreExecuted<Value>(
    _ commands: [(_ command: String) throws -> String],
    whenExecuting block: () throws -> Value
  ) throws -> Value {
    try ensureAllInvocationsAreExecuted(commands.map { block in
      { command, _, _, _ in
        TerminalResult(exitCode: 1, output: try block(command))
      }
    }, whenExecuting: block)
  }

  /// Returns the result of the block, ensuring that all the provided commands are called in the expected order, and that no other command is called during the execution.
  public func ensureAllInvocationsAreExecuted<Value>(
    _ commands: [(_ command: String, _ input: String?, _ quiet: Bool, _ cwd: String?) throws -> TerminalResult],
    whenExecuting block: () throws -> Value
  ) throws -> Value {
    var _commands = commands
    var error: Error? = nil

    onRunTerminalCommand = { command, input, quiet, cwd in
      print("Running \(command)")
      guard !_commands.isEmpty else {
        let err = UnexpectedCommandError(command: command)
        error = err
        throw err
      }
      return try _commands.removeFirst()(command, input, quiet, cwd)
    }

    let result = try block()

    if !_commands.isEmpty {
      throw UncalledCommandError()
    }
    if let error {
      throw error
    }
    return result
  }
}
