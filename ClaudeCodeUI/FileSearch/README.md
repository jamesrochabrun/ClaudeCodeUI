# Inline File Search

This folder contains all components for the inline file search feature that allows users to search for files using the `@` symbol in the chat input.

## Structure

```
FileSearch/
├── Models/
│   └── FileResult.swift          # Data model for search results
├── ViewModels/
│   └── FileSearchViewModel.swift # ViewModel managing search state
├── Views/
│   └── InlineFileSearchView.swift # UI component for displaying search results
└── Managers/
    ├── InlineFileSearchProtocol.swift # Protocol defining search operations
    └── InlineFileSearchManager.swift  # Spotlight-based search implementation
```

## Dependencies

The file search components integrate with:
- `XcodeObservationViewModel` - For project observation and file watching
- `FileInfo` (from XcodeWorkspaceModel) - Core file representation model

## Components

### InlineFileSearchProtocol
Defines the interface for file search operations including:
- `performSearch()` - Search by filename
- `performContentSearch()` - Search within file contents
- `updateSearchPath()` - Update the search directory
- `cancelSearch()` - Cancel ongoing operations

### InlineFileSearchManager
Implements file search using macOS Spotlight (NSMetadataQuery) with:
- Efficient file system search
- Proper cancellation support
- Content search with line matching (limited to files under 5MB)
- Dynamic search path configuration

### FileSearchViewModel
Manages the search state and UI updates:
- Debounced search queries
- Keyboard navigation support
- Dynamic result updates
- Project path management

### InlineFileSearchView
The UI component that displays:
- Search header with query and result count
- File results with icons and paths
- Keyboard navigation hints
- Empty state messaging

### FileResult
Data model representing search results with:
- File path and name
- Selection state and selection mode (keyboard/mouse)
- Matching lines (for content search)
- File type detection
- Integration with `FileInfo` model

## Usage

The file search is triggered by typing `@` in the chat input, which shows the inline search UI above the text editor.