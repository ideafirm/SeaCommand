//
//  CommandService.swift
//  demo
//
//  Created by sealua on 2026/2/18.
//

import Foundation

/// 命令执行结果
struct CommandResult {
    let output: String
    let isError: Bool
    let isAsync: Bool = false
}

/// 异步命令结果
struct AsyncCommandResult {
    let outputHandler: (@MainActor (String, Bool) -> Void)?
    let completionHandler: (@MainActor () -> Void)?
}

/// 命令处理服务
class CommandService {
    
    // MARK: - 单例
    static let shared = CommandService()
    private init() {}
    
    // MARK: - 文件管理器
    private let fileManager = FileManager.default
    
    /// SSH 服务
    private let sshService = SSHService.shared
    
    /// 获取 Documents 目录路径
    var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - 命令执行
    
    /// 执行命令
    /// - Parameter input: 用户输入的命令字符串
    /// - Returns: 命令执行结果
    func execute(_ input: String) -> CommandResult {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedInput.isEmpty else {
            return CommandResult(output: "", isError: false)
        }
        
        let parts = trimmedInput.split(separator: " ", omittingEmptySubsequences: true)
        guard let command = parts.first?.lowercased() else {
            return CommandResult(output: "", isError: false)
        }
        
        let arguments = parts.dropFirst().map { String($0) }
        
        switch command {
        case "echo":
            return handleEcho(arguments: arguments)
        case "date":
            return handleDate()
        case "ls":
            return handleListFiles(arguments: arguments)
        case "help":
            return handleHelp()
        case "clear":
            return CommandResult(output: "__CLEAR__", isError: false)
        case "touch":
            return handleTouch(arguments: arguments)
        case "rm":
            return handleRemove(arguments: arguments)
        case "cat":
            return handleCat(arguments: arguments)
        case "write":
            return handleWrite(arguments: arguments)
        case "pwd":
            return handlePwd()
        case "mkdir":
            return handleMkdir(arguments: arguments)
        case "ssh":
            return handleSSH(arguments: arguments, fullInput: trimmedInput)
        case "exit":
            return handleExit()
        case "ping":
            return handlePing(arguments: arguments)
        case "ifconfig":
            return handleIfconfig()
        case "whoami":
            return handleWhoami()
        case "hostname":
            return handleHostname()
        case "uptime":
            return handleUptime()
        case "curl":
            return handleCurl(arguments: arguments)
        default:
            return CommandResult(output: "command not found: \(command). Type 'help' for available commands.", isError: true)
        }
    }
    
    /// 异步执行命令（用于需要网络操作的命令）
    func executeAsync(_ input: String, outputHandler: @escaping @MainActor (String, Bool) -> Void, completionHandler: @escaping @MainActor () -> Void) -> Bool {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmedInput.split(separator: " ", omittingEmptySubsequences: true)
        guard let command = parts.first?.lowercased() else { return false }
        let arguments = parts.dropFirst().map { String($0) }
        
        switch command {
        case "ssh":
            handleSSHAsync(arguments: arguments, fullInput: trimmedInput, outputHandler: outputHandler, completionHandler: completionHandler)
            return true
        case "ssh-exec":
            handleSSHExecAsync(arguments: arguments, outputHandler: outputHandler, completionHandler: completionHandler)
            return true
        case "ping":
            handlePingAsync(arguments: arguments, outputHandler: outputHandler, completionHandler: completionHandler)
            return true
        default:
            return false
        }
    }
    
    // MARK: - 命令处理方法
    
    /// echo 命令：输出文本
    private func handleEcho(arguments: [String]) -> CommandResult {
        let text = arguments.joined(separator: " ")
        return CommandResult(output: text, isError: false)
    }
    
    /// date 命令：显示当前日期时间
    private func handleDate() -> CommandResult {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        formatter.locale = Locale(identifier: "zh_CN")
        let dateString = formatter.string(from: Date())
        return CommandResult(output: dateString, isError: false)
    }
    
    /// ls 命令：列出目录内容
    private func handleListFiles(arguments: [String]) -> CommandResult {
        let targetPath: URL
        
        if let path = arguments.first {
            // 支持相对路径
            if path.hasPrefix("/") {
                targetPath = URL(fileURLWithPath: path)
            } else if path == "~" || path.hasPrefix("~/") {
                let homePath = path.replacingOccurrences(of: "~", with: NSHomeDirectory())
                targetPath = URL(fileURLWithPath: homePath)
            } else {
                targetPath = documentsDirectory.appendingPathComponent(path)
            }
        } else {
            targetPath = documentsDirectory
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: targetPath, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            if contents.isEmpty {
                return CommandResult(output: "(empty directory)", isError: false)
            }
            
            let output = contents.map { url -> String in
                let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                return isDirectory ? "📁 \(url.lastPathComponent)/" : "📄 \(url.lastPathComponent)"
            }.sorted().joined(separator: "\n")
            
            return CommandResult(output: output, isError: false)
        } catch {
            return CommandResult(output: "ls: cannot access '\(arguments.first ?? "")': No such file or directory", isError: true)
        }
    }
    
    /// help 命令：显示帮助信息
    private func handleHelp() -> CommandResult {
        let help = """
        Available commands:
        
        File Operations:
          echo [text]        - Print text to terminal
          ls [path]          - List directory contents (default: Documents)
          pwd                - Print working directory
          touch <file>       - Create an empty file
          rm <file>          - Remove a file
          cat <file>         - Display file contents
          write <file> <text>- Write text to file
          mkdir <dir>        - Create a directory
        
        Network Commands:
          ssh user@host [-p port] - Connect to SSH server
          ssh-login <password>    - Login with password
          ssh-exec <command>      - Execute command on SSH server
          exit                    - Disconnect SSH session
          ping <host>             - Test host reachability
          ifconfig                - Show network interfaces
          curl <url>              - HTTP request (use curl-async for async)
        
        System Commands:
          date               - Show current date and time
          whoami             - Show current user
          hostname           - Show device hostname
          uptime             - Show system uptime
        
        Terminal:
          clear              - Clear the terminal screen
          help               - Show this help message
        
        SSH Usage:
          1. ssh root@124.221.35.221        - Initiate connection
          2. ssh-login your_password        - Enter password
          3. ssh-exec ls -la                - Run remote command
          4. exit                           - Disconnect
        """
        return CommandResult(output: help, isError: false)
    }
    
    /// pwd 命令：显示当前工作目录
    private func handlePwd() -> CommandResult {
        return CommandResult(output: documentsDirectory.path, isError: false)
    }
    
    /// touch 命令：创建空文件
    private func handleTouch(arguments: [String]) -> CommandResult {
        guard let fileName = arguments.first else {
            return CommandResult(output: "touch: missing file operand", isError: true)
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            // 更新修改时间
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: fileURL.path)
        } else {
            fileManager.createFile(atPath: fileURL.path, contents: nil, attributes: nil)
        }
        
        return CommandResult(output: "", isError: false)
    }
    
    /// rm 命令：删除文件
    private func handleRemove(arguments: [String]) -> CommandResult {
        guard let fileName = arguments.first else {
            return CommandResult(output: "rm: missing operand", isError: true)
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try fileManager.removeItem(at: fileURL)
            return CommandResult(output: "", isError: false)
        } catch {
            return CommandResult(output: "rm: cannot remove '\(fileName)': \(error.localizedDescription)", isError: true)
        }
    }
    
    /// cat 命令：显示文件内容
    private func handleCat(arguments: [String]) -> CommandResult {
        guard let fileName = arguments.first else {
            return CommandResult(output: "cat: missing file operand", isError: true)
        }
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return CommandResult(output: "cat: \(fileName): No such file or directory", isError: true)
        }
        
        do {
            let contents = try String(contentsOf: fileURL, encoding: .utf8)
            return CommandResult(output: contents.isEmpty ? "(empty file)" : contents, isError: false)
        } catch {
            return CommandResult(output: "cat: cannot read '\(fileName)': \(error.localizedDescription)", isError: true)
        }
    }
    
    /// write 命令：写入文件
    private func handleWrite(arguments: [String]) -> CommandResult {
        guard arguments.count >= 2 else {
            return CommandResult(output: "write: usage: write <file> <text>", isError: true)
        }
        
        let fileName = arguments[0]
        let text = arguments.dropFirst().joined(separator: " ")
        
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return CommandResult(output: "", isError: false)
        } catch {
            return CommandResult(output: "write: cannot write to '\(fileName)': \(error.localizedDescription)", isError: true)
        }
    }
    
    /// mkdir 命令：创建目录
    private func handleMkdir(arguments: [String]) -> CommandResult {
        guard let dirName = arguments.first else {
            return CommandResult(output: "mkdir: missing operand", isError: true)
        }
        
        let dirURL = documentsDirectory.appendingPathComponent(dirName)
        
        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            return CommandResult(output: "", isError: false)
        } catch {
            return CommandResult(output: "mkdir: cannot create directory '\(dirName)': \(error.localizedDescription)", isError: true)
        }
    }
    
    // MARK: - SSH 命令处理
    
    /// SSH 命令：同步版本，返回提示信息
    private func handleSSH(arguments: [String], fullInput: String) -> CommandResult {
        // 检查是否是 SSH 模式下的命令执行
        if sshService.isConnected {
            return CommandResult(output: "Use 'ssh-exec <command>' to execute commands on remote server, or 'exit' to disconnect.", isError: false)
        }
        
        // 解析 SSH 连接参数
        guard let params = SSHService.parseSSHCommand(fullInput) else {
            return CommandResult(output: "ssh: invalid syntax. Usage: ssh user@host [-p port]", isError: true)
        }
        
        return CommandResult(output: "Connecting to \(params.username)@\(params.host):\(params.port)...\nEnter password with: ssh-login <password>", isError: false)
    }
    
    /// SSH 异步连接处理
    private func handleSSHAsync(arguments: [String], fullInput: String, outputHandler: @escaping @MainActor (String, Bool) -> Void, completionHandler: @escaping @MainActor () -> Void) {
        Task {
            // 如果已连接，显示状态
            if sshService.isConnected {
                await outputHandler("Already connected to: \(sshService.getConnectionInfo())\nUse 'ssh-exec <command>' to run commands.\nUse 'exit' to disconnect.", false)
                await completionHandler()
                return
            }
            
            // 解析连接参数
            guard let params = SSHService.parseSSHCommand(fullInput) else {
                await outputHandler("ssh: invalid syntax. Usage: ssh user@host [-p port]", true)
                await completionHandler()
                return
            }
            
            await outputHandler("Connecting to \(params.username)@\(params.host):\(params.port)...", false)
            
            // 这里需要密码，暂时返回提示
            await outputHandler("\nPassword required.\nUsage: ssh-login <password>", false)
            await completionHandler()
        }
    }
    
    /// SSH 命令执行（异步）
    private func handleSSHExecAsync(arguments: [String], outputHandler: @escaping @MainActor (String, Bool) -> Void, completionHandler: @escaping @MainActor () -> Void) {
        Task {
            guard sshService.isConnected else {
                await outputHandler("ssh: not connected. Use 'ssh user@host' first.", true)
                await completionHandler()
                return
            }
            
            let command = arguments.joined(separator: " ")
            guard !command.isEmpty else {
                await outputHandler("ssh-exec: missing command", true)
                await completionHandler()
                return
            }
            
            let result = await sshService.executeCommand(command)
            await outputHandler(result, false)
            await completionHandler()
        }
    }
    
    /// Exit 命令：断开 SSH 连接
    private func handleExit() -> CommandResult {
        if sshService.isConnected {
            sshService.disconnect()
            return CommandResult(output: "SSH connection closed.", isError: false)
        }
        return CommandResult(output: "", isError: false)
    }
    
    // MARK: - 网络命令处理
    
    /// Ping 命令（同步版本）
    private func handlePing(arguments: [String]) -> CommandResult {
        guard let host = arguments.first else {
            return CommandResult(output: "ping: usage: ping <host>", isError: true)
        }
        return CommandResult(output: "Use 'ping-async \(host)' for async ping (requires network access).", isError: false)
    }
    
    /// Ping 异步处理
    private func handlePingAsync(arguments: [String], outputHandler: @escaping @MainActor (String, Bool) -> Void, completionHandler: @escaping @MainActor () -> Void) {
        guard let host = arguments.first else {
            Task { @MainActor in
                outputHandler("ping: usage: ping <host>", true)
                completionHandler()
            }
            return
        }
        
        Task {
            await outputHandler("PING \(host)...", false)
            
            // 测试 TCP 连接到常用端口
            let reachable = await testHostReachability(host: host, port: 80)
            
            if reachable {
                await outputHandler("Host \(host) is reachable on port 80", false)
            } else {
                await outputHandler("Host \(host) is not reachable", false)
            }
            
            await completionHandler()
        }
    }
    
    /// 测试主机可达性
    private func testHostReachability(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
                if socket < 0 {
                    continuation.resume(returning: false)
                    return
                }
                
                defer { close(socket) }
                
                var timeout = timeval(tv_sec: 3, tv_usec: 0)
                setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(port).bigEndian
                
                if inet_pton(AF_INET, host, &addr.sin_addr) <= 0 {
                    if let hostent = gethostbyname(host) {
                        memcpy(&addr.sin_addr, hostent.pointee.h_addr_list[0], Int(hostent.pointee.h_length))
                    } else {
                        continuation.resume(returning: false)
                        return
                    }
                }
                
                let result = withUnsafePointer(to: &addr) { ptr in
                    ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                        Darwin.connect(socket, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
                
                continuation.resume(returning: result == 0)
            }
        }
    }
    
    /// ifconfig 命令：显示网络接口信息
    private func handleIfconfig() -> CommandResult {
        var output = "Network Interfaces:\n"
        
        // 获取本机 IP
        var addresses: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }
                
                guard let interface = ptr?.pointee else { continue }
                let name = String(cString: interface.ifa_name)
                
                if interface.ifa_addr.pointee.sa_family == UInt8(AF_INET) {
                    var addr = interface.ifa_addr.pointee
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(&addr, socklen_t(interface.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST)
                    let ip = String(cString: hostname)
                    addresses.append("\(name): \(ip)")
                }
            }
            freeifaddrs(ifaddr)
        }
        
        output += addresses.isEmpty ? "  No active interfaces found\n" : addresses.map { "  \($0)" }.joined(separator: "\n") + "\n"
        
        // WiFi 信息（如果可用）
        output += "\nNote: Limited network info on iOS due to sandbox restrictions."
        
        return CommandResult(output: output, isError: false)
    }
    
    /// whoami 命令：显示当前用户
    private func handleWhoami() -> CommandResult {
        let username = NSUserName()
        return CommandResult(output: username, isError: false)
    }
    
    /// hostname 命令：显示设备名称
    private func handleHostname() -> CommandResult {
        let hostname = ProcessInfo.processInfo.hostName
        return CommandResult(output: hostname, isError: false)
    }
    
    /// uptime 命令：显示运行时间
    private func handleUptime() -> CommandResult {
        let uptime = ProcessInfo.processInfo.systemUptime
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        let seconds = Int(uptime) % 60
        return CommandResult(output: String(format: "up %d:%02d:%02d", hours, minutes, seconds), isError: false)
    }
    
    /// curl 命令：HTTP 请求（简化版）
    private func handleCurl(arguments: [String]) -> CommandResult {
        guard let url = arguments.first else {
            return CommandResult(output: "curl: usage: curl <url>", isError: true)
        }
        
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
            return CommandResult(output: "curl: invalid URL. Must start with http:// or https://", isError: true)
        }
        
        return CommandResult(output: "Use 'curl-async \(url)' for async HTTP request.", isError: false)
    }
}
