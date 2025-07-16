import XCTest
@testable import TerminalServiceInterface

/// Tests the functionality defined in the extension of the `TerminalService` protocol.
final class TerminalServiceTests: XCTestCase {

  func test_output_noErrorOutput_returnsStdout() async throws {
    let service = MockTerminalService()

    service.onRunTerminalCommand = { _, _, _, _ in
      TerminalResult(exitCode: 1, output: "Hello, World!", errorOutput: nil)
    }

    let output = try await service.output("random")
    XCTAssertEqual(output, "Hello, World!")
  }

  func test_output_hasErrorOutput_returnsNil() async throws {
    let service = MockTerminalService()

    service.onRunTerminalCommand = { _, _, _, _ in
      TerminalResult(exitCode: 0, output: nil, errorOutput: "💣!")
    }

    let output = try await service.output("random")
    XCTAssertEqual(output, nil)
  }
}
