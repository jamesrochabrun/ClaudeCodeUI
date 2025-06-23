import XCTest
@testable import TerminalService

final class DefaultTerminalServiceTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    terminalService = DefaultTerminalService()
  }

  func test_output_LS() async throws {
    let output = try await terminalService.output("ls")
    XCTAssertEqual(output?.isEmpty, false)
  }

  func test_output_LSFile() async throws {
    let output = try await terminalService.output("ls", cwd: "/")
    XCTAssertEqual(output?.contains("Applications"), true)
  }

  func test_output_CWD() async throws {
    let output = try await terminalService.output("ls", cwd: FileManager.default.homeDirectoryForCurrentUser.path)
    XCTAssertEqual(output?.contains("Desktop"), true)
  }

  func test_runTerminal_exit33Result() async throws {
    let result = try await terminalService.runTerminal("exit 33")
    XCTAssertEqual(result.exitCode, 33)
  }

  func test_runTerminal_exit0Result() async throws {
    let result = try await terminalService.runTerminal("exit 0")
    XCTAssertEqual(result.exitCode, 0)
  }

  func test_runTerminal_STDOUT() async throws {
    let result = try await terminalService.runTerminal("echo 'Hello, World!'")
    XCTAssertEqual(result.output, "Hello, World!")
  }

  func test_runTerminal_STDERR() async throws {
    let result = try await terminalService.runTerminal("echo 'Hello, Error World!' 1>&2")
    XCTAssertEqual(result.errorOutput, "Hello, Error World!")
  }

  func test_runTerminal_STDIN() async throws {
    let result = try await terminalService.runTerminal("cat", input: "Hello, STDIN!")
    XCTAssertEqual(result.output, "Hello, STDIN!")
  }

  func test_runTerminal_CWD() async throws {
    let result = try await terminalService.runTerminal("pwd", cwd: "/Library/LaunchDaemons")
    XCTAssertEqual(result.output, "/Library/LaunchDaemons")
  }

  /// Call a script which prints to STDOUT
  func test_scriptSTDOUT() async throws {
    // Path that is "wait_to_print.sh" relative to this file
    let path = URL(fileURLWithPath: #file)
      .deletingLastPathComponent()
      .path

    _ = try await terminalService.output("./simple_output.sh", cwd: path)
  }

  /// Call a script which is known to deadlock while waiting for a listener
  /// on STDOUT
  func test_deadlockCase() async throws {
    let expectation = XCTestExpectation(description: "timeout")

    let task = Task {
      // Run script which only successfully finishes running when a STDOUT listener exists
      let scriptPath = URL(fileURLWithPath: #file)
        .deletingLastPathComponent()
        .appendingPathComponent("SwiftPrintTest.swift")
        .path

      let output = try await terminalService.runTerminal("swift \(scriptPath)")
      XCTAssertEqual(output.exitCode, 0)
      XCTAssert(output.output?.contains("Hello from Swift") == true)
      expectation.fulfill()
    }

    await fulfillment(of: [expectation], timeout: 20)
    task.cancel()
  }

  // MARK: Private

  // MARK: - Shell.output

  private var terminalService: DefaultTerminalService!
}
