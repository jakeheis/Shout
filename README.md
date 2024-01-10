# Shout

[![Build Status](https://github.com/jakeheis/Shout/workflows/Test/badge.svg)](https://github.com/jakeheis/Shout/actions)

SSH made easy in Swift

```swift
import Shout

let ssh = try SSH(host: "example.com")
try ssh.authenticate(username: "user", privateKey: "~/.ssh/id_rsa")
try ssh.execute("ls -a")
try ssh.execute("pwd")
...
```

## Installation
### [Ice Package Manager](https://github.com/jakeheis/Ice)
```shell
> ice add jakeheis/Shout
```
### Swift Package Manager
Add Shout as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/jakeheis/Shout", from: "0.5.5")
]
```

## Usage

### Creating a session
You create a session by passing a host and optionally a port (default 22):
```swift
let ssh = try SSH(host: "example.com")
// or
let ssh = try SSH(host: "example.com", port: 22)
```

### Authenticating

You can authenticate with a private key, a password, or an agent.

#### Private key

To authenticate with a private key, you must pass the username and the path to the private key. You can also pass the path to the public key (defaults to the private key path + ".pub") and the passphrase encrypting the key (defaults to nil for no passphrase)

```swift
session.authenticate(username: "user", privateKey: "~/.ssh/id_rsa")
// or
session.authenticate(username: "user", privateKey: "~/.ssh/id_rsa", publicKey: "~/.ssh/id_rsa.pub", passphrase: "passphrase")
```

#### Password
Simply pass the username and password:
```swift
session.authenticate(username: "user", password: "password")
```

#### Agent
If you've already added the necessary private key to ssh-agent, you can authenticate using the agent:
```swift
session.authenticateByAgent(username: "user")
```

### Executing commands

You can remotely execute a command one of two ways. `session.execute` will print the output of the command to stdout and return the status of the command, while `session.capture` will not print anything to stdout and will return both the status and the output of the command as a string.
```swift
let status = try session.execute("ls -a")
let (status, output) = try session.capture("pwd")
```

### Send files

You can send a local file to a remote path, similar to the `scp` command line program, with `sendFile`.
```swift
let status = try session.sendFile(localURL: myLocalFile, remotePath: "~/cats.png")
```

### SFTP

You can open an SFTP session with the remote server:

```swift
let sftp = try session.openSftp()
try sftp.download(remotePath: "/a/remote/file", localURL: myLocalFile)
try sftp.upload(localURL: myLocalFile, remotePath: "~/cats.png")
```

### Configuration

You can instruct the session to request a pty (pseudo terminal) before executing commands:
```swift
session.ptyType = .vanilla
```
