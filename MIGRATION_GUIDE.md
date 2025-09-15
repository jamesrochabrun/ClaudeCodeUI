# Database Migration Guide for ClaudeCodeContainer

> **IMPORTANT**: This guide is for the **simplified, officially supported session management system** using `ClaudeCodeContainer` and `SimplifiedClaudeCodeSQLiteStorage`. If you're using a custom storage implementation, this guide does not apply.

## Overview

This guide explains how to safely modify the database schema when using the simplified ClaudeCodeUI session management system. The migration system ensures existing users' data remains intact when you release updates with schema changes.

**Related Documentation**: See [SESSION_MANAGEMENT.md](SESSION_MANAGEMENT.md) for complete session management architecture.

## Quick Start Checklist

When you need to change the database schema:

- [ ] Create a new migration struct in `SimplifiedClaudeCodeSQLiteMigrations.swift`
- [ ] Register the migration in `getMigrations()` method
- [ ] Increment `CURRENT_SCHEMA_VERSION` constant
- [ ] Test the migration with sample data
- [ ] Document any breaking changes
- [ ] Commit with clear message about schema changes

## When You Need a Migration

You need a migration when:
- Adding new columns to existing tables
- Creating new tables
- Adding or removing indexes
- Transforming existing data formats
- Renaming columns or tables
- Changing column types

You DON'T need a migration for:
- Code-only changes (no database impact)
- Changes to in-memory data structures
- UI updates
- Bug fixes that don't touch the schema

## Step-by-Step Process

### 1. Create Your Migration

Add a new migration struct at the bottom of `SimplifiedClaudeCodeSQLiteMigrations.swift`:

```swift
struct MigrationV2_YourFeatureName: DatabaseMigration {
  var version: Int { 2 }  // Next version number
  var description: String { "Clear description of what this migration does" }

  func migrate(database: Connection) async throws {
    try database.transaction {
      // Your migration code here
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN your_new_field TEXT DEFAULT NULL
      """)
    }
  }

  // Optional: Only if rollback is possible
  func rollback(database: Connection) async throws {
    try database.transaction {
      // Rollback code (if possible)
    }
  }
}
```

### 2. Register Your Migration

In `SimplifiedClaudeCodeSQLiteMigrations.swift`, find the `getMigrations()` method and add your migration:

```swift
private func getMigrations(from currentVersion: Int, to targetVersion: Int) -> [DatabaseMigration] {
  var migrations: [DatabaseMigration] = []

  // Add your migration here
  if currentVersion < 2 {
    migrations.append(MigrationV2_YourFeatureName())
  }

  // Future migrations go here
  // if currentVersion < 3 {
  //   migrations.append(MigrationV3_AnotherFeature())
  // }

  return migrations
}
```

### 3. Update Schema Version

In `SimplifiedClaudeCodeSQLiteMigrations.swift`, update the version constant:

```swift
public static let CURRENT_SCHEMA_VERSION = 2  // Was 1, now 2
```

### 4. Test Your Migration

Create a test database with version 1 data and verify:
1. Migration runs without errors
2. Existing data is preserved
3. New schema works correctly
4. App functions normally after migration

## Migration Patterns

### Adding a Nullable Column

```swift
struct MigrationV2_AddUserPreferences: DatabaseMigration {
  var version: Int { 2 }
  var description: String { "Add user preferences to sessions" }

  func migrate(database: Connection) async throws {
    try database.transaction {
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN user_preferences TEXT DEFAULT NULL
      """)
    }
  }
}
```

### Adding a Non-Nullable Column with Default

```swift
struct MigrationV2_AddThemeMode: DatabaseMigration {
  var version: Int { 2 }
  var description: String { "Add theme mode with default value" }

  func migrate(database: Connection) async throws {
    try database.transaction {
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN theme_mode TEXT NOT NULL DEFAULT 'light'
      """)
    }
  }
}
```

### Creating a New Table

```swift
struct MigrationV2_AddBookmarksTable: DatabaseMigration {
  var version: Int { 2 }
  var description: String { "Create bookmarks table" }

  func migrate(database: Connection) async throws {
    try database.transaction {
      try database.execute("""
        CREATE TABLE IF NOT EXISTS bookmarks (
          id TEXT PRIMARY KEY,
          session_id TEXT NOT NULL,
          message_id TEXT NOT NULL,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          note TEXT,
          FOREIGN KEY(session_id) REFERENCES sessions(id) ON DELETE CASCADE,
          FOREIGN KEY(message_id) REFERENCES messages(id) ON DELETE CASCADE
        )
      """)
    }
  }
}
```

### Adding an Index

```swift
struct MigrationV2_AddPerformanceIndexes: DatabaseMigration {
  var version: Int { 2 }
  var description: String { "Add indexes for better query performance" }

  func migrate(database: Connection) async throws {
    try database.transaction {
      try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_messages_timestamp
        ON messages(timestamp DESC)
      """)

      try database.execute("""
        CREATE INDEX IF NOT EXISTS idx_sessions_working_directory
        ON sessions(working_directory)
      """)
    }
  }
}
```

### Data Transformation

```swift
struct MigrationV2_NormalizeUsernames: DatabaseMigration {
  var version: Int { 2 }
  var description: String { "Normalize username format" }

  func migrate(database: Connection) async throws {
    try database.transaction {
      // Add new column
      try database.execute("""
        ALTER TABLE sessions
        ADD COLUMN normalized_username TEXT
      """)

      // Transform existing data
      let sessions = Table("sessions")
      let idCol = Expression<String>("id")
      let usernameCol = Expression<String?>("username")

      for row in try database.prepare(sessions.select(idCol, usernameCol)) {
        if let username = row[usernameCol] {
          let normalized = username.lowercased().trimmingCharacters(in: .whitespaces)
          let query = sessions.filter(idCol == row[idCol])
          try database.run(query.update(Expression<String?>("normalized_username") <- normalized))
        }
      }
    }
  }
}
```

## Testing Your Migration

### Manual Testing Steps

1. **Backup your development database**:
   ```bash
   cp ~/Library/Application\ Support/ClaudeCodeUI/claude_code_sessions.sqlite ~/Desktop/backup.sqlite
   ```

2. **Reset database to previous version**:
   ```bash
   sqlite3 ~/Library/Application\ Support/ClaudeCodeUI/claude_code_sessions.sqlite "PRAGMA user_version = 1"
   ```

3. **Run the app** and verify migration executes

4. **Check the logs** for migration messages:
   ```
   [Migration] Current database version: 1
   [Migration] Target version: 2
   [Migration] Running migration to version 2: Your migration description
   [Migration] Successfully migrated to version 2
   ```

5. **Verify data integrity** - check that existing sessions and messages are intact

### Automated Testing

If you have test infrastructure set up:

```swift
func testMigrationV2() async throws {
  // Create v1 database with test data
  let testDb = createV1TestDatabase()

  // Run migration
  let migrationManager = SimplifiedClaudeCodeSQLiteMigrationManager(
    database: testDb,
    databasePath: testPath
  )
  try await migrationManager.runMigrationsIfNeeded()

  // Verify schema changes
  XCTAssertTrue(columnExists("new_column", in: "sessions"))

  // Verify data preservation
  XCTAssertEqual(getSessionCount(), originalSessionCount)
}
```

## Deployment Checklist

Before releasing an update with schema changes:

### Pre-Release
- [ ] Migration tested with production-like data
- [ ] Rollback strategy documented (if applicable)
- [ ] Release notes mention database upgrade
- [ ] Version number incremented in `CURRENT_SCHEMA_VERSION`
- [ ] Migration registered in `getMigrations()`

### Post-Release Monitoring
- [ ] Monitor crash reports for migration errors
- [ ] Check user feedback for data loss issues
- [ ] Verify telemetry shows successful migrations
- [ ] Have rollback plan ready if issues arise

## Troubleshooting

### Common Issues and Solutions

#### Migration Runs Every Time
**Problem**: Migration executes on every app launch
**Solution**: Ensure you're calling `setVersion()` after successful migration

#### Foreign Key Constraint Violations
**Problem**: Migration fails with foreign key errors
**Solution**: Ensure parent records exist before adding child records, or temporarily disable foreign keys:
```swift
try database.execute("PRAGMA foreign_keys = OFF")
// Run migration
try database.execute("PRAGMA foreign_keys = ON")
```

#### Migration Partially Completes
**Problem**: Migration fails halfway through
**Solution**: Always use transactions to ensure atomicity:
```swift
try database.transaction {
  // All migration steps here
}
```

#### Users Stuck on Old Version
**Problem**: Some users report old app behavior
**Solution**: Check logs to ensure migration ran. May need to add recovery code:
```swift
if databaseIsCorrupted() {
  try resetToFreshDatabase()
}
```

## Best Practices

1. **Always use DEFAULT values** - Existing rows need values for new columns
2. **Make columns nullable when possible** - Provides flexibility
3. **Test with real data** - Use a copy of production database
4. **Keep migrations small** - One logical change per migration
5. **Document breaking changes** - In release notes and code comments
6. **Use transactions** - Ensure atomicity of changes
7. **Never modify past migrations** - Only add new ones
8. **Version migrations clearly** - Use descriptive names like `MigrationV2_AddUserSettings`

## Migration System Architecture

The migration system for ClaudeCodeContainer consists of:

- **SimplifiedClaudeCodeSQLiteStorage**: Initializes and calls migration manager
- **SimplifiedClaudeCodeSQLiteMigrationManager**: Orchestrates migration execution
- **DatabaseMigration protocol**: Interface for individual migrations
- **Version tracking**: Uses SQLite's `PRAGMA user_version`
- **Backup system**: Creates backups before migrations
- **Validation**: Checks database integrity after migrations

## Important Notes

- This guide is **ONLY** for the simplified ClaudeCodeContainer system
- Custom storage implementations need their own migration strategy
- Migrations run automatically on app startup when needed
- Users cannot downgrade to older app versions (protection in place)
- Backups are created but not automatically restored (manual recovery if needed)

## Getting Help

If you encounter issues:

1. Check the [SESSION_MANAGEMENT.md](SESSION_MANAGEMENT.md) for architecture details
2. Review existing migrations in `SimplifiedClaudeCodeSQLiteMigrations.swift`
3. Look at migration logs with `[Migration]` prefix
4. Test thoroughly in development before release

Remember: Database migrations affect user data. Always err on the side of caution and test thoroughly.