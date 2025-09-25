import Foundation
import SQLite

// MARK: - Migration System for Simplified ClaudeCodeContainer

/// This migration system is specifically for the simplified, officially supported
/// session management system using ClaudeCodeContainer and SimplifiedClaudeCodeSQLiteStorage.
///
/// For detailed migration instructions, see MIGRATION_GUIDE.md
///
/// IMPORTANT: This is NOT for custom storage implementations.
/// Custom storage systems need their own migration strategy.

// MARK: - DatabaseMigration Protocol

/// Protocol defining a database migration
protocol DatabaseMigration {
  /// The version this migration upgrades to
  var version: Int { get }

  /// Human-readable description of what this migration does
  var description: String { get }

  /// Execute the migration
  func migrate(database: Connection) async throws

  /// Rollback the migration (optional)
  func rollback(database: Connection) async throws
}

// Default implementation for rollback (most migrations don't need rollback)
extension DatabaseMigration {
  func rollback(database: Connection) async throws {
    // Default: no rollback available
    throw MigrationError.rollbackNotSupported(version: version)
  }
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError {
  case invalidVersion(current: Int, target: Int)
  case migrationFailed(version: Int, underlying: Error)
  case backupFailed(Error)
  case rollbackNotSupported(version: Int)
  case databaseCorrupted

  var errorDescription: String? {
    switch self {
    case .invalidVersion(let current, let target):
      return "Invalid migration: current version \(current) cannot migrate to \(target)"
    case .migrationFailed(let version, let error):
      return "Migration to version \(version) failed: \(error.localizedDescription)"
    case .backupFailed(let error):
      return "Failed to backup database: \(error.localizedDescription)"
    case .rollbackNotSupported(let version):
      return "Rollback not supported for version \(version)"
    case .databaseCorrupted:
      return "Database appears to be corrupted"
    }
  }
}

// MARK: - Migration Manager

/// Manages database schema migrations for SimplifiedClaudeCodeSQLiteStorage
/// This is part of the official ClaudeCodeContainer session management system
public actor SimplifiedClaudeCodeSQLiteMigrationManager {

  /// Current schema version - increment this when adding new migrations
  /// Version 1: Initial schema with sessions, messages, and attachments tables
  /// Version 2: Add git worktree support (branch_name, is_worktree columns)
  ///
  /// WHEN ADDING MIGRATIONS: Update this to the new version number
  /// See MIGRATION_GUIDE.md for instructions
  public static let CURRENT_SCHEMA_VERSION = 2

  private let database: Connection
  private let databasePath: String

  public init(database: Connection, databasePath: String) {
    self.database = database
    self.databasePath = databasePath
  }

  /// Get the current database schema version
  public func getCurrentVersion() throws -> Int {
    let version = try database.scalar("PRAGMA user_version") as? Int64 ?? 0
    return Int(version)
  }

  /// Set the database schema version
  private func setVersion(_ version: Int) throws {
    try database.execute("PRAGMA user_version = \(version)")
  }

  /// Run any pending migrations
  public func runMigrationsIfNeeded() async throws {
    let currentVersion = try getCurrentVersion()

    print("[Migration] Current database version: \(currentVersion)")
    print("[Migration] Target version: \(SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)")

    // Guard against downgrade attempts
    if currentVersion > SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION {
      print("[Migration] WARNING: Database version (\(currentVersion)) is newer than app version (\(SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION))")
      print("[Migration] This might indicate running an older app version. Proceeding without migration.")
      return
    }

    // If we're already at the current version, nothing to do
    if currentVersion == SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION {
      print("[Migration] Database is up to date")
      return
    }

    // If this is a fresh database (version 0), just set to current version
    if currentVersion == 0 {
      print("[Migration] Fresh database detected, setting to version \(SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)")
      try setVersion(SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)
      return
    }

    // Backup before migrations
    try await createBackup()

    // Get migrations to run
    let migrations = getMigrations(from: currentVersion, to: SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)

    if migrations.isEmpty {
      print("[Migration] No migrations to run")
      try setVersion(SimplifiedClaudeCodeSQLiteMigrationManager.CURRENT_SCHEMA_VERSION)
      return
    }

    // Run migrations sequentially
    try await runMigrations(migrations)
  }

  /// Get all migrations that need to run
  ///
  /// IMPORTANT: When you need to add a new migration:
  /// 1. Create your migration struct below (see examples at bottom of file)
  /// 2. Register it here by adding an if statement
  /// 3. Update CURRENT_SCHEMA_VERSION at the top of this file
  ///
  /// See MIGRATION_GUIDE.md for detailed instructions
  private func getMigrations(from currentVersion: Int, to targetVersion: Int) -> [DatabaseMigration] {
    var migrations: [DatabaseMigration] = []

    // Register migrations
    if currentVersion < 2 {
      migrations.append(MigrationV2_AddWorktreeSupport())
    }
    // if currentVersion < 3 {
    //   migrations.append(MigrationV3_AnotherFeature())
    // }

    return migrations
  }

  /// Run migrations sequentially
  /// Note: Each migration is responsible for its own transaction management
  /// This allows complex migrations to use multiple transactions if needed
  private func runMigrations(_ migrations: [DatabaseMigration]) async throws {
    print("[Migration] Running \(migrations.count) migrations")

    for migration in migrations {
      print("[Migration] Running migration to version \(migration.version): \(migration.description)")

      do {
        // Run migration - migration is responsible for transaction management
        try await migration.migrate(database: database)

        // Update version immediately after successful migration
        // This should ideally be atomic with the migration, but SQLite.swift
        // doesn't support async transactions. The risk window is minimal.
        try setVersion(migration.version)
        print("[Migration] Successfully migrated to version \(migration.version)")

      } catch {
        print("[Migration] Failed to migrate to version \(migration.version): \(error)")

        // Attempt rollback if available
        do {
          try await migration.rollback(database: database)
          print("[Migration] Rolled back migration version \(migration.version)")
        } catch {
          print("[Migration] Rollback failed or not available: \(error)")
        }

        throw MigrationError.migrationFailed(version: migration.version, underlying: error)
      }
    }

    print("[Migration] All migrations completed successfully")
  }

  /// Create a backup of the database
  private func createBackup() async throws {
    let fileManager = FileManager.default
    let backupPath = databasePath + ".backup_\(Date().timeIntervalSince1970)"

    print("[Migration] Creating backup at: \(backupPath)")

    do {
      // SQLite backup using VACUUM INTO (creates a fresh, optimized copy)
      try database.execute("VACUUM INTO '\(backupPath)'")
      print("[Migration] Backup created successfully")
    } catch {
      print("[Migration] Backup failed: \(error)")
      throw MigrationError.backupFailed(error)
    }
  }

  /// Validate database integrity
  public func validateDatabase() async throws {
    let result = try database.scalar("PRAGMA integrity_check") as? String

    if result != "ok" {
      print("[Migration] Database integrity check failed: \(result ?? "unknown")")
      throw MigrationError.databaseCorrupted
    }

    print("[Migration] Database integrity check passed")
  }

  /// Clean up old backup files (keep only last 3)
  public func cleanupOldBackups() async throws {
    let fileManager = FileManager.default
    let directory = URL(fileURLWithPath: databasePath).deletingLastPathComponent()

    do {
      let files = try fileManager.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: [.creationDateKey],
        options: .skipsHiddenFiles
      )

      // Filter backup files
      let backupFiles = files.filter { url in
        url.lastPathComponent.contains(".backup_")
      }

      // Sort by creation date (newest first)
      let sortedBackups = backupFiles.sorted { url1, url2 in
        let date1 = try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
        let date2 = try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate ?? Date.distantPast
        return date1! > date2!
      }

      // Keep only the 3 most recent backups
      if sortedBackups.count > 3 {
        for backup in sortedBackups.dropFirst(3) {
          try fileManager.removeItem(at: backup)
          print("[Migration] Removed old backup: \(backup.lastPathComponent)")
        }
      }
    } catch {
      print("[Migration] Failed to cleanup old backups: \(error)")
      // Non-critical error, don't throw
    }
  }
}

// MARK: - Actual Migrations

// Migration to add git worktree support
struct MigrationV2_AddWorktreeSupport: DatabaseMigration {
  var version: Int { 2 }
  var description: String { "Add git worktree support (branch_name, is_worktree columns)" }

  func migrate(database: Connection) async throws {
    // Wrap migration in transaction for atomicity
    try database.transaction {
      // Add branch_name column (nullable for backwards compatibility)
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN branch_name TEXT DEFAULT NULL
      """)

      // Add is_worktree column with default false
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN is_worktree INTEGER DEFAULT 0
      """)
    }
  }
}

// MARK: - Example Migrations

// Example migration for adding a new field (for future use)
// BEST PRACTICE: Include version update in the same transaction when possible
struct MigrationV3_AddUserPreferences: DatabaseMigration {
  var version: Int { 3 }
  var description: String { "Add user_preferences field to sessions table" }

  func migrate(database: Connection) async throws {
    // Wrap migration in transaction for atomicity
    try database.transaction {
      // Add new nullable column
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN user_preferences TEXT DEFAULT NULL
      """)

      // Note: Version update happens outside this transaction due to
      // architectural constraints, but the risk window is minimal
    }
  }
}

// Example migration for adding an index (for future use)
struct MigrationV4_AddIndexes: DatabaseMigration {
  var version: Int { 4 }
  var description: String { "Add indexes for better query performance" }

  func migrate(database: Connection) async throws {
    // Example: Add indexes for common queries with transaction
    try database.transaction {
      try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_messages_session_id_timestamp
        ON messages(session_id, timestamp)
      """)

      try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_sessions_last_accessed
        ON sessions(last_accessed_at)
      """)
    }
  }
}

// Example migration for data transformation (for future use)
struct MigrationV5_TransformData: DatabaseMigration {
  var version: Int { 5 }
  var description: String { "Transform legacy data format" }

  func migrate(database: Connection) async throws {
    // Example: Transform existing data with transaction
    try database.transaction {
      let messagesTable = Table("messages")
      let idColumn = Expression<String>("id")
      let contentColumn = Expression<String>("content")

      // Read and transform data
      for row in try database.prepare(messagesTable.select(idColumn, contentColumn)) {
        let messageId = row[idColumn]
        let oldContent = row[contentColumn]

        // Transform content (example)
        let newContent = transformContent(oldContent)

        // Update row
        let query = messagesTable.filter(idColumn == messageId)
        try database.run(query.update(contentColumn <- newContent))
      }
    }
  }

  private func transformContent(_ content: String) -> String {
    // Example transformation
    return content
  }
}