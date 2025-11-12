# Disk Speed Test - Interactive TUI

A lightweight, interactive bash script that measures disk read and write speeds with real-time progress bars and live speed calculations.

## Features

- **Real-time Progress Bars** - Visual feedback with percentage completion for both read and write tests
- **Live Speed Calculations** - Watch MB/s speed update in real-time as each block completes
- **Interactive TUI** - Clean, user-friendly terminal interface with colored output
- **Accurate Measurements** - Tests 500MB total (500 × 1MB blocks) with proper fsync flushing
- **Results Summary** - Final report showing both write and read speeds

## Requirements

- Bash 4.0+
- `dd` command (standard on most Unix-like systems)
- `bc` for floating-point calculations
- At least 500MB of free disk space

## Installation

```bash
git clone <repository-url>
cd disk-speed-test
chmod +x disk_speed_TUI.sh
```

## Usage

```bash
./disk_speed_TUI.sh
```

The script will:
1. Display a header with test information
2. Run the write speed test (creates 500MB file with progress bar)
3. Run the read speed test (reads the file back with progress bar)
4. Clean up temporary test files
5. Display a summary with final speeds in MB/s
6. Prompt you to press Enter to exit

## Output Example

```
╔═══════════════════════════════════════════════╗
║      💾 Disk Speed Test - Interactive TUI     ║
╚═══════════════════════════════════════════════╝

Starting Write Speed Test...
File Size: 500 MB | Location: /home/user/.speed_test_temp

Write Test      [========================================] 100% 450.25 MB/s

✓ Write Speed: 450.25 MB/s (1109ms)

Starting Read Speed Test...
File Size: 500 MB | Location: /home/user/.speed_test_temp

Read Test       [========================================] 100% 1200.50 MB/s

✓ Read Speed: 1200.50 MB/s (416ms)

=== Test Results ===

  Write Speed:         450.25 MB/s
  Read Speed:          1200.50 MB/s
```

## How It Works

### Write Test
- Creates a test file by writing 1MB blocks sequentially
- Uses `dd` with `conv=fdatasync` to ensure data is actually written to disk
- Tracks elapsed time to calculate real-time speed
- Updates progress bar after each block

### Read Test
- Reads the previously created test file in 1MB increments
- Uses random block access pattern (via `skip` parameter)
- Calculates speed based on total blocks read and elapsed time
- Displays live speed calculations

### Cleanup
- Automatically removes the temporary test file after completion
- Removes temporary speed result files

## Customization

You can modify these variables at the top of the script:

```bash
TEST_FILE="$HOME/.speed_test_temp"  # Location of test file
FILE_SIZE="500M"                    # Total size to test
BLOCK_SIZE="1M"                     # Size per block
TOTAL_BLOCKS=500                    # Number of blocks
```

## Performance Considerations

- **Accuracy**: The script uses `fdatasync` to ensure writes are committed to disk, giving realistic write speeds
- **Block Size**: 1MB blocks provide a good balance between granular progress updates and test duration
- **Test Duration**: Full test typically takes 30-60 seconds depending on disk speed
- **Temporary Files**: Test files are stored in your home directory (can be changed via `TEST_FILE` variable)

## Troubleshooting

### Script won't run
```bash
chmod +x disk_speed_TUI.sh
```

### "bc: command not found"
Install bc:
```bash
# Ubuntu/Debian
sudo apt-get install bc

# macOS
brew install bc

# Fedora/RHEL
sudo dnf install bc
```

### Not enough disk space
The script requires 500MB of free space. You can reduce `TOTAL_BLOCKS` or `FILE_SIZE` if needed.

### Inaccurate results
- Ensure no other processes are writing to the disk
- Close unnecessary applications to reduce I/O contention
- Run multiple times and average the results for consistency

## Color Coding

- **Blue**: Section headers and test starts
- **Green**: Success messages and live speed values
- **Yellow**: Warnings and prompts
- **Cyan**: Labels and test result headers

## License

MIT License - Feel free to use and modify as needed.

## Contributing

Contributions are welcome! Feel free to submit issues or pull requests for improvements.
