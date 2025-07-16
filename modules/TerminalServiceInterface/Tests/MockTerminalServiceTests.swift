import XCTest
@testable import TerminalServiceInterface

final class MockTerminalServiceTests: XCTestCase {
  func test_runTerminal_callsOnRunShellCommandClosure() async throws {
    let service = MockTerminalService()
    let expectedCommand = "ls"
    let expectedInput = "./"
    let expectedQuiet = false
    let expectedCwd = "../apps"
    let onRunTerminalCommandExpectation = expectation(description: "onRunTerminalCommand called")

    service.onRunTerminalCommand = { command, input, quiet, cwd in
      XCTAssertEqual(command, expectedCommand)
      XCTAssertEqual(input, expectedInput)
      XCTAssertEqual(quiet, expectedQuiet)
      XCTAssertEqual(cwd, expectedCwd)
      onRunTerminalCommandExpectation.fulfill()
      return TerminalResult(exitCode: 1, output: "foo", errorOutput: nil)
    }

    let result = try await service.runTerminal(expectedCommand, input: expectedInput, quiet: expectedQuiet, cwd: expectedCwd)
    await fulfillment(of: [onRunTerminalCommandExpectation], timeout: 1)
  }

  func test_runTerminal_returnsResultOfOnRunShellCommandClosure() async throws {
    let service = MockTerminalService()

    service.onRunShellCommand = { _, _, _, _ in
      ShellResult(exitCode: 1, output: "foo", errorOutput: nil)
    }

    let result = try await service.runTerminal("random")
    XCTAssertEqual(result.exitCode, 1)
    XCTAssertEqual(result.output, "foo")
  }

  func test_output_callsOnRunShellCommandClosure() async throws {
    let service = MockTerminalService()
    let expectedCommand = "echo Hello, World!"
    let expectedCwd = "/path/to/directory"
    let terminalExpectation = expectation(description: "onRunTerminalCommand called")

    service.onRunTerminalCommand = { command, input, quiet, cwd in
      XCTAssertEqual(command, expectedCommand)
      XCTAssertEqual(cwd, expectedCwd)
      XCTAssertEqual(input, nil)
      XCTAssertEqual(quiet, false)
      terminalExpectation.fulfill()
      return TerminalResult(exitCode: 1, output: "Hello, World!", errorOutput: nil)
    }

    let result = try await service.output(expectedCommand, cwd: expectedCwd)
    await fulfillment(of: [terminalExpectation], timeout: 1)
  }
}
