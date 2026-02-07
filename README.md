# OpenTerm

A native macOS terminal application with SSH, RDP, and local terminal support, built with SwiftUI.

## Features

### Local Terminal
- Native local shell terminal (zsh/bash)
- Auto-opens on app launch if no sessions exist
- Multiple local terminal tabs supported
- Same customization options as SSH terminals (fonts, colors)
- Session logging support

### Multi-Session Mode
- Display all terminal sessions in a grid view
- Broadcast keyboard input to all terminals simultaneously
- Per-terminal exclusion checkbox to skip specific sessions
- Multi-paste button to paste clipboard content to all terminals
- Automatic grid layout (1-4 sessions: 2 columns, 5+ sessions: 3 columns)

### SSH Terminal
- Full terminal emulation with SwiftTerm
- Password and public key authentication
- SFTP file browser with drag-and-drop support
- Session logging to file
- Customizable terminal colors and fonts
- X11 forwarding support
- Post-login command execution with configurable delay

### SFTP Text Editor
- Floating, resizable, and draggable editor window
- In-memory file editing with direct SSH-based saving
- Monospaced font with line numbers
- Status bar showing cursor position, line count, and file size
- Word wrap toggle
- Unsaved changes detection with save/discard prompts
- Find functionality (⌘F)
- UTF-8 and ASCII encoding support

### RDP (Remote Desktop)
- Native RDP client powered by FreeRDP
- Multiple display modes: Fit to Window, Fullscreen, Fixed resolution
- Performance profiles:
  - **Best Quality**: 32-bit color, H.264 + AVC444, all visual effects
  - **Balanced**: 24-bit color, H.264, some effects disabled
  - **Best Performance**: 16-bit color, bitmap caching, maximum compatibility
- Clipboard sharing
- Sound redirection (local/remote)
- Drive redirection

### Connection Management
- Organize connections in folders
- Tags and notes for each connection
- Custom icons per connection
- Duplicate and rename connections
- "Connect as" different user

### Password Manager
- Encrypted password vault with AES-GCM
- PBKDF2 key derivation
- Automatic or manual password saving

## Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3/M4)

## Installation

1. Download the latest release from [Releases](../../releases)
2. Extract the zip file
3. Drag `OpenTerm.app` to your Applications folder
4. On first launch, right-click → Open → Open to bypass Gatekeeper

## Building from Source

### Prerequisites

- Xcode 15.0 or later
- [Homebrew](https://brew.sh) (for building FreeRDP)

### Build Steps

```bash
# Clone the repository
git clone https://github.com/yourusername/OpenTerm.git
cd OpenTerm

# Open in Xcode
open OpenTerm.xcodeproj

# Build (Cmd+B) or Run (Cmd+R)
```

The FreeRDP libraries are pre-built and included in the `vendor/` directory. If you need to rebuild them:

```bash
cd OpenTerm/scripts
./build_freerdp.sh
```

## Libraries & Dependencies

### Swift Packages

| Library | Description | License |
|---------|-------------|---------|
| [SwiftTerm](https://github.com/migueldeicaza/SwiftTerm) | Terminal emulator for Swift | MIT |
| [Shout](https://github.com/jakeheis/Shout) | SSH library for Swift | MIT |

### Native Libraries

| Library | Description | License |
|---------|-------------|---------|
| [FreeRDP](https://github.com/FreeRDP/FreeRDP) | Free RDP client implementation | Apache 2.0 |
| [OpenSSL](https://github.com/openssl/openssl) | Cryptography and TLS toolkit | Apache 2.0 |

### System Frameworks

- AppKit
- SwiftUI
- Foundation
- Security (for AES-GCM encryption)
- CryptoKit (for PBKDF2)

## Project Structure

```
OpenTerm/
├── OpenTerm/
│   ├── Models.swift              # Data models (Connection, Folder, etc.)
│   ├── ContentView.swift         # Main application view
│   ├── SidebarView.swift         # Connection list sidebar
│   ├── SessionTabsView.swift     # Tab management for sessions
│   ├── SessionStore.swift        # Session state management
│   ├── ConnectionDetailView.swift # Connection editor
│   ├── TerminalSession.swift     # SSH terminal session
│   ├── RdpSession.swift          # RDP session wrapper
│   ├── OpenTermRdpClient.m/h     # Objective-C FreeRDP bridge
│   ├── OpenTermTerminalView.swift # Custom terminal view
│   ├── SFTPManager.swift         # SFTP operations
│   ├── SFTPBrowserView.swift     # SFTP file browser UI
│   ├── SFTPTextEditorView.swift  # SFTP remote file editor UI
│   ├── SFTPEditorWindowController.swift # Floating editor window manager
│   ├── PasswordVault.swift       # Encrypted password storage
│   ├── ConnectionStore.swift     # Connection persistence
│   ├── SettingsStore.swift       # App settings
│   └── vendor/
│       └── FreeRDP/              # Pre-built FreeRDP libraries
└── README.md
```

## Data Storage

- **Connections**: `~/Library/Application Support/OpenTerm/connections.json`
- **Settings**: `~/Library/Application Support/OpenTerm/settings.json`
- **Password Vault**: `~/Library/Application Support/OpenTerm/vault.json`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [FreeRDP](https://www.freerdp.com/) team for the excellent RDP implementation
- [Miguel de Icaza](https://github.com/migueldeicaza) for SwiftTerm
- [Jake Heis](https://github.com/jakeheis) for Shout SSH library

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request
