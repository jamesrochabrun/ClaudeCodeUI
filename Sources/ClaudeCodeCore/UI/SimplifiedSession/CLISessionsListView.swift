//
//  CLISessionsListView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 1/9/26.
//

import Foundation
import SwiftUI

// MARK: - CLISessionsListView

/// Main list view for displaying CLI sessions with repository-based organization
struct CLISessionsListView: View {
  @Bindable var viewModel: CLISessionsViewModel

  var body: some View {
    VStack(spacing: 0) {
      // Add repository button (always visible)
      CLIRepositoryPickerView(onAddRepository: viewModel.showAddRepositoryPicker)
        .padding(.horizontal, 12)
        .padding(.top, 8)

      if viewModel.isLoading && !viewModel.hasRepositories {
        loadingView
      } else if !viewModel.hasRepositories {
        CLIEmptyStateView(onAddRepository: viewModel.showAddRepositoryPicker)
      } else {
        repositoriesList
      }
    }
  }

  // MARK: - Loading View

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle())
      Text(viewModel.loadingState.message)
        .font(.caption)
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Repositories List

  private var repositoriesList: some View {
    ScrollView {
      LazyVStack(spacing: 12) {
        // Status header
        statusHeader

        // Repository tree views
        ForEach(viewModel.selectedRepositories) { repository in
          CLIRepositoryTreeView(
            repository: repository,
            onRemove: { viewModel.removeRepository(repository) },
            onToggleExpanded: { viewModel.toggleRepositoryExpanded(repository) },
            onToggleWorktreeExpanded: { worktree in
              viewModel.toggleWorktreeExpanded(in: repository, worktree: worktree)
            },
            onConnectSession: { session in
              if let error = viewModel.connectToSession(session) {
                print("Failed to connect: \(error.localizedDescription)")
              }
            },
            onCopySessionId: { session in
              viewModel.copySessionId(session)
            }
          )
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
  }

  // MARK: - Status Header

  private var statusHeader: some View {
    VStack(spacing: 8) {
      // Loading indicator (when loading with repositories)
      if viewModel.isLoading {
        HStack(spacing: 8) {
          ProgressView()
            .scaleEffect(0.7)
          Text(viewModel.loadingState.message)
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
      }

      HStack {
        // Session count
        if viewModel.activeSessionCount > 0 {
          HStack(spacing: 4) {
            Circle()
              .fill(Color.green)
              .frame(width: 6, height: 6)
            Text("\(viewModel.activeSessionCount) active")
              .font(.caption)
              .foregroundColor(.green)
          }
        }

        Text("\(viewModel.totalSessionCount) total sessions")
          .font(.caption)
          .foregroundColor(.secondary)

        Spacer()

        // Refresh button
        Button(action: viewModel.refresh) {
          Image(systemName: "arrow.clockwise")
            .font(.caption)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
        .help("Refresh sessions")
      }
    }
    .padding(.horizontal, 4)
  }
}

// MARK: - Preview

#Preview {
  let service = CLISessionMonitorService()
  let viewModel = CLISessionsViewModel(monitorService: service)

  return CLISessionsListView(viewModel: viewModel)
    .frame(width: 400, height: 600)
}
