# Backup Manager 2024

Backup Manager 2024 is a powerful and efficient shell script designed to manage backups on Debian 12 x86_64 systems. It simplifies the process of creating, maintaining, and managing `.tar.gz` backups of specified files and directories.

## Features

- **Multiple Backup Modes** (coming soon):
  - **Check all (Default)**: Checks the contents of all other `.tar.gz` files in the destination directory, deleting files that match or are subsets of the new backup.
  - **Delete all**: Deletes all other `.tar.gz` files in the destination directory.
  - **Keep all**: Retains all other `.tar.gz` files in the destination directory.
- **Error Handling**: Robust error handling with customizable messages and exit codes.
- **Efficient Array Comparison**: Compares arrays to determine if they are equal, subsets, or distinct.
- **Path Processing**: Effectively handles file and directory paths for seamless backup operations.

## Requirements

- `tar` and `pigz` installed

## Installation

Clone the repository and navigate to the project directory:

```bash
cd $HOME
git clone https://github.com/ammr01/backup-manager-2024.git
cd backup-manager-2024
echo "1 * * * * $USER "
```

## Usage

```bash
./backup_manager.sh <directories/files to backup (separated by space)> -d <backup destination directory> [--tar_arguments <arguments>]
```

### Options

- `-h, --help`: Display the help message and exit.
- `--tar_arguments <arguments>`: Additional arguments for the `tar` command.
- `-d, --directory, --destination <directory>`: Specify the backup destination directory.

### Example

Create a backup of `/home/user/documents` and `/etc` directories, and store it in `/home/user/backups`:

```bash
./backup_manager.sh /home/user/documents /etc -d /home/user/backups 
```

## Important Notes

- **File Names**: The script is not designed to handle file or directory names containing newlines.
- **Destination Directory**: It is recommended to use an empty destination directory when using the default mode.


## Future Updates

- **Exclusion Lists**: Adding support for exclusion lists.
- **Backup Modes**: Implementing different backup modes (Check all, Delete all, Keep all).

---

Feel free to contribute to this project by reporting issues, suggesting features, or submitting pull requests. Happy backing up!
