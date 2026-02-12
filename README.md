# beaver

A lightweight, high-performance log rotation tool that reads from stdin, writes to log files, and automatically rotates and compresses them based on configurable limits.

## Features

- **Automatic Log Rotation**: Rotates logs based on three configurable criteria:
  - Line count limit
  - File size limit
  - File age limit (time-based rotation)
- **Automatic Compression**: Compresses rotated log files using zstd with maximum compression
- **Non-blocking Compression**: Uses Crystal fibers for asynchronous compression
- **Symlink Management**: Maintains a consistent log file name via symlinks for easy access
- **Timestamped Archives**: Rotated files are named with UTC timestamps for easy identification
- **Stdin Processing**: Reads from stdin, making it easy to pipe output from any program

## Installation

### From Source

Requires Crystal 1.9.2 or later.

```bash
# Clone the repository
git clone https://github.com/wwalker/beaver.git
cd beaver

# Install dependencies
shards install

# Build the binary
shards build --release

# The binary will be available at ./bin/beaver
```

### Using Docker Build

The project includes a Docker-based build script for creating static binaries:

```bash
./build
```

This uses the Crystal 1.11.2-alpine Docker image to create a statically-linked binary.

## Usage

```bash
beaver <filename> <line_limit> <file_size_limit> <file_age_limit>
```

### Parameters

- **filename**: The base name of the log file to write to (a symlink will be created with this name)
- **line_limit**: Maximum number of lines per log file before rotation
- **file_size_limit**: Maximum file size in bytes before rotation
- **file_age_limit**: Maximum age of log file in seconds before rotation

### Options

```bash
beaver --help          # Show usage information
beaver --version       # Show version number
beaver --version-full  # Show detailed version and build information
```

### Examples

#### Basic Usage

Rotate logs every 10,000 lines, 10MB, or 1 hour (whichever comes first):

```bash
tail -f /var/log/app.log | beaver app.log 10000 10485760 3600
```

#### Process Application Output

```bash
./myapp | beaver myapp.log 50000 104857600 86400
```

This configuration will rotate when:
- The log reaches 50,000 lines, OR
- The log reaches 100MB (104857600 bytes), OR
- The log is 24 hours old (86400 seconds)

#### Docker Container Logs

```bash
docker logs -f mycontainer | beaver container.log 100000 52428800 43200
```

Rotates every 100,000 lines, 50MB, or 12 hours.

## How It Works

1. **Initialization**: On startup, if the target filename exists:
   - If it's a symlink, it's deleted
   - If it's a regular file, it's renamed with a timestamp

2. **Logging**:
   - Creates a new timestamped log file
   - Creates a symlink from the base filename to the timestamped file
   - Reads from stdin line by line and writes to the current log file

3. **Rotation**: When any of the three limits is reached:
   - Closes the current log file
   - Creates a new timestamped log file
   - Updates the symlink to point to the new file
   - Spawns a background fiber to compress the old file with zstd

4. **Compression**:
   - Uses zstd with `-9` (maximum compression) and `-T0` (multi-threaded)
   - Removes the original file after compression (`--rm`)
   - Runs asynchronously using Crystal fibers

5. **Shutdown**: Waits for all compression jobs to complete before exiting

## File Naming

Log files are named with UTC timestamps in the format:

```
<filename>.YYYY-MM-DDTHH.MM.SS.9NNNNNNNNNZ
```

For example:
```
app.log -> app.log.2024-10-10T15.30.45.912345678Z (symlink)
app.log.2024-10-10T15.30.45.912345678Z
app.log.2024-10-10T14.25.30.123456789Z.zst
app.log.2024-10-10T13.15.20.987654321Z.zst
```

## Development

### Prerequisites

- Crystal 1.9.2 or later
- zstd compression tool (required at runtime)

### Running Tests

```bash
crystal spec
```

### Building

```bash
# Development build
shards build

# Production build with optimizations
shards build --release

# Static build using Docker
./build
```

### Dependencies

- [shard.cr](https://github.com/maiha/shard.cr) - Provides version and metadata information

## Performance Considerations

- **Memory Efficient**: Processes input line by line, minimal memory footprint
- **Non-blocking**: Compression happens in background fibers, doesn't block log writing
- **Fast Compression**: zstd provides excellent compression ratios with good speed
- **Minimal Overhead**: Written in Crystal for native performance

## Use Cases

- Long-running application log management
- Continuous integration/deployment log archival
- Container log rotation and compression
- System service log management
- High-volume log processing with automatic size management

## Contributing

1. Fork it (https://github.com/wwalker/beaver/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [Wayne Walker](https://github.com/wwalker) - creator and maintainer
- [Jaime Fournier](https://github.com/ober) - creator and maintainer

## License

MIT License - see [LICENSE](LICENSE) file for details
