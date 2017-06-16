# Shout
SSH made easy in Swift
```swift
import Shout

let session = try SSH.Session(host: "example.com")
try session.authenticate(username: "user", privateKey: "~/.ssh/id_rsa")
try session.execute("ls -a")
try session.execute("pwd")
...
```

## Installation
Add Shout as a dependency to your project:
```swift
dependencies: [
    .Package(url: "https://github.com/jakeheis/Shout", majorVersion: 0, minor: 1)
]
```