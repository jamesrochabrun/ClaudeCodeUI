# Session Management Documentation

## Overview

This document describes the **simplified session management system** in ClaudeCodeUI, which is the officially supported approach using `ClaudeCodeContainer`. This system provides persistent storage of Claude Code conversations using SQLite, ensuring users can restore previous sessions and continue conversations seamlessly.

## Architecture

### Core Components

```
┌─────────────────────────┐
│   ClaudeCodeContainer   │  (UI Orchestrator)
│  - Session UI management│
│  - Session picker       │
└───────────┬─────────────┘
            │
┌───────────▼─────────────┐
│ SimplifiedSessionManager│  (Business Logic)
│  - Session lifecycle    │
│  - Start/restore/delete │
└───────────┬─────────────┘
            │
┌───────────▼──────────────────┐
│SimplifiedClaudeCodeSQLiteStorage│  (Persistence)
│  - SQLite database operations│
│  - Message chaining           │
└──────────────────────────────┘
```

### Database Schema

The system uses SQLite with three tables connected by foreign key relationships:

```
┌──────────────────────┐
│      sessions        │
├──────────────────────┤
│ id (PRIMARY KEY)     │◄──┐
│ created_at           │   │
│ first_user_message   │   │ Foreign Key
│ last_accessed_at     │   │ (CASCADE DELETE)
│ working_directory    │   │
└──────────────────────┘   │
                           │
┌──────────────────────┐   │
│      messages        │   │
├──────────────────────┤   │
│ id (PRIMARY KEY)     │◄──┼──┐
│ session_id ──────────┼───┘  │
│ content              │      │ Foreign Key
│ role                 │      │ (CASCADE DELETE)
│ timestamp            │      │
│ message_type         │      │
│ tool_name            │      │
│ tool_input_data      │      │
│ is_error             │      │
│ is_complete          │      │
│ was_cancelled        │      │
│ task_group_id        │      │
│ is_task_container    │      │
└──────────────────────┘      │
                              │
┌──────────────────────┐      │
│     attachments      │      │
├──────────────────────┤      │
│ id (PRIMARY KEY)     │      │
│ message_id ──────────┼──────┘
│ file_name            │
│ file_path            │
│ file_type            │
└──────────────────────┘
```

### Database Location

The SQLite database is stored at:
```
~/Library/Application Support/ClaudeCodeUI/claude_code_sessions.sqlite
```

## Data Flow

### 1. Session Creation Flow

```
User sends first message
        │
        ▼
ChatViewModel stores message
        │
        ▼
StreamProcessor receives init event
        │
        ▼
SessionManager.startNewSession()
        │
        ▼
SQLiteStorage.saveSession()
        │
        ▼
Session record created in DB
```

### 2. Message Persistence Flow

Messages are persisted using a **replace-all strategy**:

```
Stream completes
        │
        ▼
ChatViewModel.saveCurrentSessionMessages()
        │
        ▼
Get all messages from MessageStore
        │
        ▼
SQLiteStorage.updateSessionMessages()
        │
        ├─► Delete existing messages for session
        │
        └─► Insert all current messages
```

This ensures message integrity and proper ordering.

### 3. Session Restoration Flow

```
User selects session from picker
        │
        ▼
SimplifiedSessionManager.restoreSession()
        │
        ▼
Load fresh data from SQLiteStorage
        │
        ▼
ChatViewModel.injectSession()
        │
        ▼
MessageStore.loadMessages()
        │
        ▼
Reload availableSessions for UI update
```

## Message Chaining

Messages within a session are linked through the `session_id` foreign key. The chaining works as follows:

1. **Session Identity**: Each session has a unique ID (UUID string)
2. **Message Association**: All messages contain a `session_id` field linking them to their parent session
3. **Temporal Ordering**: Messages are ordered by their `timestamp` field
4. **Message Types**: The system handles various message types:
   - `text`: Regular user/assistant messages
   - `toolUse`: Tool invocation requests
   - `toolResult`: Tool execution results
   - `error`: Error messages

### Example Message Chain

For a command like "pwd", the message chain looks like:

```
Session: 3dfa533d-462b-4ad3-b328-ef06dcce5b21
│
├─► Message 1: role=user, type=text, content="pwd"
├─► Message 2: role=assistant, type=text, content="I'll show you..."
├─► Message 3: role=toolUse, type=toolUse, toolName="Bash"
├─► Message 4: role=toolResult, type=toolResult, content="/Users/..."
└─► Message 5: role=assistant, type=text, content="You're in..."
```

## Session ID Management

### Dynamic Session IDs

Session IDs can change during a conversation:

1. **Temporary ID**: ChatViewModel may start with a temporary session ID
2. **Official ID**: Claude API provides the official session ID via StreamProcessor
3. **ID Update**: The system updates all references when the ID changes

```swift
// In SimplifiedClaudeCodeSQLiteStorage.updateSessionId()
1. Create new session record with new ID
2. Update all message foreign keys
3. Delete old session record
```

This ensures foreign key constraints are maintained.

## Single Source of Truth

The database is the **single source of truth** for session data:

- **Always Load Fresh**: When showing the session picker, always load from database
- **No Stale Cache**: Avoid displaying cached `availableSessions` without refreshing
- **Post-Operation Refresh**: After any session operation (restore, create, delete), reload sessions

## Important Considerations

### 1. Foreign Key Constraints

- Foreign keys are enabled: `PRAGMA foreign_keys = ON`
- Cascade deletes ensure data integrity
- Order matters when updating session IDs

### 2. Tool Messages

Tool messages (like bash commands) create multiple message entries:
- User request
- Assistant acknowledgment
- Tool use message
- Tool result message
- Assistant summary

All must be preserved and restored correctly.

### 3. Working Directory

Each session stores its working directory:
- Used to restore proper context
- Falls back to global preference if not set
- Updated when session is restored

## Troubleshooting

### Issue: Session shows wrong message count
**Solution**: Ensure `loadAvailableSessions()` is called after session operations to refresh the UI with database state.

### Issue: Foreign key constraint violation
**Solution**: When updating session IDs, create the new session record before updating message foreign keys.

### Issue: Missing tool messages
**Solution**: Ensure all message types are properly serialized/deserialized, especially `toolUse` and `toolResult` types.

### Issue: Session not persisting
**Solution**: Verify that `saveCurrentSessionMessages()` is called after stream completion and that the session ID is properly set.

## API Usage

### Starting a New Session

```swift
sessionManager.startNewSession(
    chatViewModel: chatViewModel,
    workingDirectory: "/path/to/project"
)
```

### Restoring a Session

```swift
await sessionManager.restoreSession(
    session: storedSession,
    chatViewModel: chatViewModel
)
```

### Loading Available Sessions

```swift
let sessions = try await sessionManager.loadAvailableSessions()
```

## Best Practices

1. **Always use ClaudeCodeContainer** - This is the officially supported approach
2. **Let the database be the source of truth** - Don't rely on in-memory state for persistence
3. **Log extensively during development** - Use prefixed logs (e.g., "[zizou]") for debugging
4. **Handle session ID changes gracefully** - They can change during streaming
5. **Preserve all message types** - Including tool messages for complete conversation history

## Summary

The simplified session management system provides a robust, SQLite-based solution for persisting Claude Code conversations. By maintaining the database as the single source of truth and properly handling message chaining through foreign key relationships, the system ensures reliable session storage and restoration while supporting complex conversation flows including tool usage.