//
//  MCPConfigStorage.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import Foundation

@MainActor
protocol MCPConfigStorage {
  func setMcpConfigPath(_ path: String)
}
