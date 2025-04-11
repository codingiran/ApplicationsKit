# ApplicationsKit

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2010.15%2B-blue.svg)](https://developer.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A powerful Swift library for macOS that provides easy access to application information and process management.

## Features

- **Application Information**
  - Get detailed information about installed applications
  - Access system and user applications
  - Retrieve application metadata including bundle identifier, version, and architecture
  - Support for wrapped applications and web apps
  - Application icon fetching with caching support

- **Process Management**
  - Get information about running processes
  - Access process details including PID, UID, user, and command
  - Monitor system processes

## Requirements

- macOS 10.15 or later
- Swift 5.9 or later
- Xcode 15.0 or later (for development)

## Installation

### Swift Package Manager

Add ApplicationsKit to your project using Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/codingiran/ApplicationsKit.git", from: "0.0.2")
]
```

## Usage

### Getting Application Information

```swift
import ApplicationsKit

// Get all system applications
let systemApps = ApplicationsKit.systemApplications()

// Get all user applications
let userApps = ApplicationsKit.userApplications()

// Get applications from a specific directory
let customApps = ApplicationsKit.applications(at: customDirectory)
```

### Accessing Process Information

```swift
import ApplicationsKit

// Get all running processes
let processes = ProcessStatus.all()

// Access process details
for process in processes {
    print("PID: \(process.pid)")
    print("User: \(process.user)")
    print("Command: \(process.command)")
}
```

### Application Icon Management

```swift
import ApplicationsKit

// Get application icon
let icon = await ApplicationIcon.shared.icon(for: application)

// Get icon with specific size
let sizedIcon = await ApplicationIcon.shared.icon(for: application, preferedSize: NSSize(width: 64, height: 64))
```

## Documentation

For detailed documentation, please refer to the source code comments and the example project.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

ApplicationsKit is available under the MIT license. See the [LICENSE](LICENSE) file for more info.

## Contact

- Email: codingiran@gmail.com
- GitHub: [@codingiran](https://github.com/codingiran)

## Acknowledgments

- Thanks to all contributors who have helped improve this project
- Special thanks to the Swift community for their support and inspiration