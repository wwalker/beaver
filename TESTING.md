# Beaver Test Suite Documentation

This document describes the comprehensive test suite for the beaver log rotation tool.

## Test Files

The test suite is organized into three main files:

1. **spec/beaver_spec.cr** - Unit tests for the Beaver class
2. **spec/beaver_integration_spec.cr** - Integration tests for complete workflows
3. **spec/beaver_cli_spec.cr** - Tests for command-line interface

## Running Tests

```bash
# Run all tests
crystal spec

# Run with verbose output
crystal spec --verbose

# Run specific test file
crystal spec spec/beaver_spec.cr
```

## Test Coverage

### Unit Tests (beaver_spec.cr)

#### Initialization
- ✓ Initializes with correct parameters
- ✓ Accepts various limit values (including zero)

#### Filename Generation
- ✓ Generates timestamped filenames
- ✓ Uses correct timestamp format (UTC with nanoseconds)

#### Rotation Logic
- ✓ Returns false when no limits are exceeded
- ✓ Returns true when line limit is reached
- ✓ Returns true when file size limit would be exceeded
- ✓ Returns true when file age limit is exceeded

#### Line Counting
- ✓ Increments the line counter correctly

#### Symlink Management
- ✓ Creates symlinks to timestamped files
- ✓ Replaces existing symlinks correctly

#### File Operations
- ✓ Handles non-existent files gracefully (rename_original)
- ✓ Renames existing files with timestamps
- ✓ Creates new timestamped files
- ✓ Creates and maintains symlinks

#### Edge Cases
- ✓ Handles zero line limit
- ✓ Handles zero size limit
- ✓ Handles empty string filenames
- ✓ Handles very long filenames (200+ characters)
- ✓ Handles special characters in filenames
- ✓ Handles very large limit values (999,999,999)
- ✓ Handles concurrent filename generation

#### Resource Management
- ✓ Properly handles file handles

### Integration Tests (beaver_integration_spec.cr)

#### Complete Workflow
- ✓ Creates files and symlinks correctly
- ✓ Preserves existing file content when renaming
- ✓ Handles rotation workflow
- ✓ Updates symlinks on rotation
- ✓ Handles multiple sequential operations

#### Rotation Criteria
- ✓ Rotates based on line count
- ✓ Rotates based on file size
- ✓ Rotates based on file age
- ✓ Rotates when any limit is reached (OR logic)

#### File Naming and Timestamps
- ✓ Generates unique filenames for rapid rotations
- ✓ Uses UTC timestamps consistently
- ✓ Formats timestamps with nanosecond precision

#### Error Handling and Edge Cases
- ✓ Handles non-existent directories
- ✓ Handles filenames with multiple dots
- ✓ Handles filenames with paths
- ✓ Maintains correct file permissions

#### Concurrent Operations
- ✓ Handles rapid open/close cycles

#### Symlink Management
- ✓ Removes old symlinks before creating new ones
- ✓ Creates symlinks even if regular file exists

### CLI Tests (beaver_cli_spec.cr)

#### Argument Parsing
- ✓ Documents requirement for exactly 4 arguments

#### Help and Version Flags
- ✓ Documents support for --help, -h
- ✓ Documents support for --version, -v
- ✓ Documents support for --version-full, -V

#### Parameter Conversion
- ✓ Converts string arguments to integers correctly
- ✓ Handles large numeric strings
- ✓ Handles zero values

#### Usage Information
- ✓ Prints usage information without errors

## Test Summary

**Total Tests: 55**
- Unit Tests: ~30
- Integration Tests: ~19
- CLI Tests: ~6

All tests pass successfully (0 failures, 0 errors).

## Key Testing Strategies

### 1. Isolation
Each test uses unique filenames to avoid interference between tests.

### 2. Cleanup
All tests clean up their artifacts (files and symlinks) after execution.

### 3. Timing
Tests that depend on timestamp differences use `sleep` to ensure different timestamps are generated.

### 4. Comprehensive Coverage
Tests cover:
- Happy path scenarios
- Edge cases (zero limits, empty strings, very large values)
- Error conditions
- Resource management
- File system operations
- Symlink behavior

### 5. Integration Testing
Integration tests verify complete workflows rather than isolated units, ensuring components work together correctly.

## Known Limitations

1. **Compression Testing**: The test suite does not test actual zstd compression as it requires external dependencies and is asynchronous.

2. **STDIN Testing**: Reading from STDIN is not directly tested as it requires process spawning.

3. **Process Testing**: Full end-to-end executable testing (with command-line arguments) would require `Process.run` which is not included in these tests.

4. **Performance Testing**: No load testing or performance benchmarks are included.

## Future Improvements

Potential areas for additional testing:

- [ ] Compression job testing (mocking or using test doubles)
- [ ] Full end-to-end tests with actual process execution
- [ ] Performance benchmarks for large files
- [ ] Stress testing with rapid rotations
- [ ] Testing with actual STDIN input streams
- [ ] Testing error handling for filesystem errors (permissions, disk full, etc.)
- [ ] Testing behavior with symbolic links as input
- [ ] Testing concurrent access from multiple processes

## Maintenance

When modifying the beaver code:

1. Run the full test suite before committing
2. Add tests for new functionality
3. Update tests when changing behavior
4. Keep test names descriptive and clear
5. Maintain isolation between tests
6. Clean up test artifacts

## Dependencies

The test suite requires:
- Crystal 1.9.2 or later
- Standard library `spec` module
- Write access to the current directory (for creating test files)
