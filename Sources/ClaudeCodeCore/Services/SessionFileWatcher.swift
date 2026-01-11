//
//  SessionFileWatcher.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 1/10/26.
//

import Foundation
import Combine

// MARK: - SessionFileWatcher

/// Service that watches session JSONL files for real-time monitoring
public actor SessionFileWatcher {

  // MARK: - Types

  /// State update for a monitored session
  public struct StateUpdate: Sendable {
    public let sessionId: String
    public let state: SessionMonitorState
  }

  // MARK: - Properties

  private var watchedSessions: [String: FileWatcherInfo] = [:]
  private nonisolated let stateSubject = PassthroughSubject<StateUpdate, Never>()
  private let claudePath: String

  /// Publisher for state updates
  public nonisolated var statePublisher: AnyPublisher<StateUpdate, Never> {
    stateSubject.eraseToAnyPublisher()
  }

  // MARK: - Initialization

  public init(claudePath: String = "~/.claude") {
    self.claudePath = NSString(string: claudePath).expandingTildeInPath
    print("[SessionFileWatcher] init with path: \(self.claudePath)")
  }

  // MARK: - Public API

  /// Start monitoring a session
  public func startMonitoring(sessionId: String, projectPath: String) {
    print("[SessionFileWatcher] startMonitoring: \(sessionId)")

    // If already monitoring, just re-emit current state
    if let existingInfo = watchedSessions[sessionId] {
      print("[SessionFileWatcher] Already monitoring session, re-emitting state: \(sessionId)")
      let state = buildMonitorState(from: existingInfo.parseResult)
      stateSubject.send(StateUpdate(sessionId: sessionId, state: state))
      return
    }

    // Find session file
    let sessionFilePath = findSessionFile(sessionId: sessionId, projectPath: projectPath)
    guard let filePath = sessionFilePath else {
      print("[SessionFileWatcher] Could not find session file for: \(sessionId)")
      return
    }

    print("[SessionFileWatcher] Found session file: \(filePath)")

    // Initial parse
    var parseResult = SessionJSONLParser.parseSessionFile(at: filePath)
    let initialState = buildMonitorState(from: parseResult)

    // Emit initial state
    stateSubject.send(StateUpdate(sessionId: sessionId, state: initialState))

    // Set up file watching
    let fileDescriptor = open(filePath, O_EVTONLY)
    guard fileDescriptor >= 0 else {
      print("[SessionFileWatcher] Could not open file for watching: \(filePath)")
      return
    }

    let source = DispatchSource.makeFileSystemObjectSource(
      fileDescriptor: fileDescriptor,
      eventMask: [.write, .extend],
      queue: DispatchQueue.global(qos: .utility)
    )

    // Track file position for incremental reading
    var filePosition = getFileSize(filePath)

    source.setEventHandler { [weak self] in
      guard let self = self else { return }

      // Read new content
      let newLines = self.readNewLines(from: filePath, startingAt: &filePosition)
      guard !newLines.isEmpty else { return }

      print("[SessionFileWatcher] \(sessionId): \(newLines.count) new lines")

      // Parse new lines
      SessionJSONLParser.parseNewLines(newLines, into: &parseResult)
      let updatedState = self.buildMonitorState(from: parseResult)

      // Emit update
      Task { @MainActor in
        self.stateSubject.send(StateUpdate(sessionId: sessionId, state: updatedState))
      }
    }

    source.setCancelHandler {
      close(fileDescriptor)
    }

    source.resume()

    // Set up status timer to re-evaluate timeout-based status every second
    // Only emits updates when status actually changes
    let statusTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
    statusTimer.schedule(deadline: .now() + 1, repeating: 1.0)

    var lastEmittedStatus: SessionStatus = parseResult.currentStatus

    statusTimer.setEventHandler { [weak self] in
      guard let self = self else { return }

      // Re-evaluate status based on current time
      SessionJSONLParser.updateCurrentStatus(&parseResult)

      // Only emit if status actually changed
      if parseResult.currentStatus != lastEmittedStatus {
        lastEmittedStatus = parseResult.currentStatus
        let updatedState = self.buildMonitorState(from: parseResult)

        Task { @MainActor in
          self.stateSubject.send(StateUpdate(sessionId: sessionId, state: updatedState))
        }
      }
    }

    statusTimer.resume()

    // Store watcher info
    watchedSessions[sessionId] = FileWatcherInfo(
      filePath: filePath,
      source: source,
      statusTimer: statusTimer,
      parseResult: parseResult
    )

    print("[SessionFileWatcher] Started monitoring: \(sessionId)")
  }

  /// Stop monitoring a session
  public func stopMonitoring(sessionId: String) {
    print("[SessionFileWatcher] stopMonitoring: \(sessionId)")

    guard let info = watchedSessions.removeValue(forKey: sessionId) else {
      return
    }

    info.source.cancel()
    info.statusTimer.cancel()
    print("[SessionFileWatcher] Stopped monitoring: \(sessionId)")
  }

  /// Get current state for a session
  public func getState(sessionId: String) -> SessionMonitorState? {
    guard let info = watchedSessions[sessionId] else { return nil }
    return buildMonitorState(from: info.parseResult)
  }

  /// Check if a session is being monitored
  public func isMonitoring(sessionId: String) -> Bool {
    watchedSessions[sessionId] != nil
  }

  /// Force refresh a session's state
  public func refreshState(sessionId: String) {
    guard let info = watchedSessions[sessionId] else { return }

    let parseResult = SessionJSONLParser.parseSessionFile(at: info.filePath)
    watchedSessions[sessionId]?.parseResult = parseResult

    let state = buildMonitorState(from: parseResult)
    stateSubject.send(StateUpdate(sessionId: sessionId, state: state))
  }

  // MARK: - Private Helpers

  private func findSessionFile(sessionId: String, projectPath: String) -> String? {
    // Session files are in: ~/.claude/projects/{encoded-path}/{sessionId}.jsonl
    let encodedPath = projectPath.replacingOccurrences(of: "/", with: "-")
    let projectsDir = "\(claudePath)/projects/\(encodedPath)"
    let sessionFile = "\(projectsDir)/\(sessionId).jsonl"

    print("[SessionFileWatcher] Looking for: \(sessionFile)")

    if FileManager.default.fileExists(atPath: sessionFile) {
      return sessionFile
    }

    // Try alternative encodings
    let alternativeEncodings = [
      projectPath.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "",
      projectPath.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: "~", with: "-")
    ]

    for encoded in alternativeEncodings {
      let altPath = "\(claudePath)/projects/\(encoded)/\(sessionId).jsonl"
      if FileManager.default.fileExists(atPath: altPath) {
        return altPath
      }
    }

    // Search in projects directory
    let projectsDirPath = "\(claudePath)/projects"
    if let contents = try? FileManager.default.contentsOfDirectory(atPath: projectsDirPath) {
      for dir in contents {
        let potentialFile = "\(projectsDirPath)/\(dir)/\(sessionId).jsonl"
        if FileManager.default.fileExists(atPath: potentialFile) {
          return potentialFile
        }
      }
    }

    return nil
  }

  private nonisolated func getFileSize(_ path: String) -> UInt64 {
    guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
          let size = attrs[.size] as? UInt64 else {
      return 0
    }
    return size
  }

  private nonisolated func readNewLines(from path: String, startingAt position: inout UInt64) -> [String] {
    guard let handle = FileHandle(forReadingAtPath: path) else { return [] }
    defer { try? handle.close() }

    let currentSize = getFileSize(path)
    guard currentSize > position else { return [] }

    do {
      try handle.seek(toOffset: position)
      let data = handle.readDataToEndOfFile()
      position = currentSize

      guard let content = String(data: data, encoding: .utf8) else { return [] }
      return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
    } catch {
      print("[SessionFileWatcher] Error reading new lines: \(error)")
      return []
    }
  }

  private nonisolated func buildMonitorState(from result: SessionJSONLParser.ParseResult) -> SessionMonitorState {
    // Convert pending tool uses
    let pendingToolUse: PendingToolUse?
    if let (_, pending) = result.pendingToolUses.first {
      pendingToolUse = PendingToolUse(
        toolName: pending.toolName,
        toolUseId: pending.toolUseId,
        timestamp: pending.timestamp,
        input: pending.input
      )
    } else {
      pendingToolUse = nil
    }

    return SessionMonitorState(
      status: result.currentStatus,
      currentTool: extractCurrentTool(from: result),
      lastActivityAt: result.lastActivityAt ?? Date(),
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
      cacheReadTokens: result.cacheReadTokens,
      cacheCreationTokens: result.cacheCreationTokens,
      messageCount: result.messageCount,
      toolCalls: result.toolCalls,
      sessionStartedAt: result.sessionStartedAt,
      model: result.model,
      gitBranch: result.gitBranch,
      pendingToolUse: pendingToolUse,
      recentActivities: result.recentActivities
    )
  }

  private nonisolated func extractCurrentTool(from result: SessionJSONLParser.ParseResult) -> String? {
    if let (_, pending) = result.pendingToolUses.first {
      return pending.toolName
    }
    return nil
  }
}

// MARK: - FileWatcherInfo

private struct FileWatcherInfo {
  let filePath: String
  let source: DispatchSourceFileSystemObject
  let statusTimer: DispatchSourceTimer
  var parseResult: SessionJSONLParser.ParseResult
}
