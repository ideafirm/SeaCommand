//
//  SSHService.swift
//  demo
//
//  Created by sealua on 2026/2/19.
//

import Foundation
import Combine

/// SSH 连接状态
enum SSHConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case authenticating
    case error(String)
    
    static func == (lhs: SSHConnectionState, rhs: SSHConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected),
             (.authenticating, .authenticating):
            return true
        case (.error(let a), .error(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// SSH 服务 - 处理 SSH 连接和命令执行
class SSHService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SSHService()
    
    // MARK: - Published Properties
    @Published var connectionState: SSHConnectionState = .disconnected
    @Published var output: String = ""
    @Published var isConnected: Bool = false
    
    // MARK: - Private Properties
    private var session: NMSSHSession?
    private var shellChannel: NMSSHChannel?
    private var sftpSession: NMSFTP?
    private var host: String = ""
    private var port: Int = 22
    private var username: String = ""
    private var password: String = ""
    private var outputQueue = DispatchQueue(label: "com.demo.ssh.output")
    
    // Shell 输出回调
    var shellOutputHandler: ((String) -> Void)?
    var shellErrorHandler: ((String) -> Void)?
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    /// 连接到 SSH 服务器
    /// - Parameters:
    ///   - host: 服务器地址
    ///   - port: 端口号（默认 22）
    ///   - username: 用户名
    ///   - password: 密码
    /// - Returns: 连接结果消息
    func connect(host: String, port: Int = 22, username: String, password: String) async -> String {
        await MainActor.run {
            self.connectionState = .connecting
        }
        
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        
        // 创建 SSH 会话
        let session = NMSSHSession(host: host, port: UInt(port), andUsername: username)
        self.session = session
        
        // 设置连接超时
        session.timeout = 30
        
        do {
            // 连接到服务器
            try session.connect()
            
            await MainActor.run {
                self.connectionState = .authenticating
            }
            
            // 密码认证
            if session.authenticate(byPassword: password) {
                await MainActor.run {
                    self.connectionState = .connected
                    self.isConnected = true
                }
                return "Connected to \(username)@\(host):\(port)"
            } else {
                // 尝试键盘交互认证
                if session.authenticateByKeyboardInteractive { challenge, prompt in
                    return password
                } {
                    await MainActor.run {
                        self.connectionState = .connected
                        self.isConnected = true
                    }
                    return "Connected to \(username)@\(host):\(port)"
                }
                
                await MainActor.run {
                    self.connectionState = .error("Authentication failed")
                    self.isConnected = false
                }
                session.disconnect()
                self.session = nil
                return "ssh: Authentication failed for \(username)@\(host)"
            }
        } catch {
            await MainActor.run {
                self.connectionState = .error(error.localizedDescription)
                self.isConnected = false
            }
            session.disconnect()
            self.session = nil
            return "ssh: connect to host \(host) port \(port): \(error.localizedDescription)"
        }
    }
    
    /// 使用私钥连接
    func connectWithKey(host: String, port: Int = 22, username: String, privateKey: String, passphrase: String? = nil) async -> String {
        await MainActor.run {
            self.connectionState = .connecting
        }
        
        self.host = host
        self.port = port
        self.username = username
        
        let session = NMSSHSession(host: host, port: UInt(port), andUsername: username)
        self.session = session
        
        session.timeout = 30
        
        do {
            try session.connect()
            
            await MainActor.run {
                self.connectionState = .authenticating
            }
            
            // 使用私钥认证
            if session.authenticate(byPrivateKey: privateKey, passphrase: passphrase) {
                await MainActor.run {
                    self.connectionState = .connected
                    self.isConnected = true
                }
                return "Connected to \(username)@\(host):\(port) (key auth)"
            } else {
                await MainActor.run {
                    self.connectionState = .error("Key authentication failed")
                    self.isConnected = false
                }
                session.disconnect()
                self.session = nil
                return "ssh: Key authentication failed for \(username)@\(host)"
            }
        } catch {
            await MainActor.run {
                self.connectionState = .error(error.localizedDescription)
                self.isConnected = false
            }
            session.disconnect()
            self.session = nil
            return "ssh: connect to host \(host) port \(port): \(error.localizedDescription)"
        }
    }
    
    /// 断开 SSH 连接
    func disconnect() {
        // 关闭 Shell 会话
        closeShell()
        
        // 关闭 SFTP 会话
        sftpSession = nil
        
        // 断开 SSH 连接
        session?.disconnect()
        session = nil
        
        host = ""
        username = ""
        password = ""
        
        DispatchQueue.main.async {
            self.connectionState = .disconnected
            self.isConnected = false
            self.output = ""
        }
    }
    
    /// 在远程服务器执行命令
    /// - Parameter command: 要执行的命令
    /// - Returns: 命令输出结果
    func executeCommand(_ command: String) async -> String {
        guard isConnected, let session = session else {
            return "ssh: not connected to any host"
        }
        
        guard session.isConnected else {
            await MainActor.run {
                self.connectionState = .disconnected
                self.isConnected = false
            }
            return "ssh: session disconnected"
        }
        
        do {
            var error: NSError?
            let output = try session.channel.execute(command, error: &error, timeout: 60)
            
            if let error = error {
                return output + "\n[Error: \(error.localizedDescription)]"
            }
            
            return output.isEmpty ? "(no output)" : output
        } catch {
            return "ssh: command execution failed: \(error.localizedDescription)"
        }
    }
    
    /// 执行命令并返回实时输出
    func executeCommandWithOutput(_ command: String, outputHandler: @escaping (String) -> Void) async -> String {
        guard isConnected, let session = session else {
            outputHandler("ssh: not connected to any host")
            return "ssh: not connected to any host"
        }
        
        guard session.isConnected else {
            await MainActor.run {
                self.connectionState = .disconnected
                self.isConnected = false
            }
            outputHandler("ssh: session disconnected")
            return "ssh: session disconnected"
        }
        
        var fullOutput = ""
        
        do {
            var error: NSError?
            let output = try session.channel.execute(command, error: &error, timeout: 300) { data in
                if let data = data, let str = String(data: data, encoding: .utf8) {
                    fullOutput += str
                    outputHandler(str)
                }
            }
            
            if let error = error {
                let errorMsg = output + "\n[Error: \(error.localizedDescription)]"
                outputHandler(errorMsg)
                return errorMsg
            }
            
            return fullOutput.isEmpty ? output : fullOutput
        } catch {
            let errorMsg = "ssh: command execution failed: \(error.localizedDescription)"
            outputHandler(errorMsg)
            return errorMsg
        }
    }
    
    // MARK: - Interactive Shell
    
    /// 启动交互式 Shell 会话
    func startShell() async -> Bool {
        guard isConnected, let session = session else {
            shellErrorHandler?("ssh: not connected")
            return false
        }
        
        do {
            let channel = session.channel
            self.shellChannel = channel
            
            // 设置终端类型和大小
            channel.ptyTerminalType = NMSSHChannelPtyTerminal.xterm
            channel.terminalWidth = 120
            channel.terminalHeight = 40
            
            // 启动 Shell
            try channel.startShell()
            
            // 设置读取回调
            channel.readHandler = { [weak self] data in
                if let data = data, let str = String(data: data, encoding: .utf8) {
                    self?.shellOutputHandler?(str)
                }
            }
            
            // 设置错误回调
            channel.errorHandler = { [weak self] error in
                self?.shellErrorHandler?("Shell error: \(error.localizedDescription)")
            }
            
            return true
        } catch {
            shellErrorHandler?("Failed to start shell: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 关闭 Shell 会话
    func closeShell() {
        shellChannel?.closeShell()
        shellChannel = nil
    }
    
    /// 向 Shell 发送数据
    func writeToShell(_ data: String) {
        guard let channel = shellChannel else { return }
        if let data = data.data(using: .utf8) {
            channel.write(data)
        }
    }
    
    /// 发送终端大小变化
    func resizeTerminal(width: Int, height: Int) {
        shellChannel?.setTerminalWidth(UInt(width), height: UInt(height))
    }
    
    // MARK: - SFTP Operations
    
    /// 初始化 SFTP 会话
    func startSFTP() async -> String {
        guard isConnected, let session = session else {
            return "ssh: not connected"
        }
        
        guard session.isConnected else {
            return "ssh: session disconnected"
        }
        
        guard session.isAuthorized else {
            return "ssh: not authorized for SFTP"
        }
        
        sftpSession = NMSFTP(session: session)
        
        if sftpSession?.connect() == true {
            return "SFTP session started"
        } else {
            sftpSession = nil
            return "Failed to start SFTP session"
        }
    }
    
    /// 列出远程目录
    func listRemoteDirectory(_ path: String = ".") async -> String {
        guard let sftp = sftpSession else {
            return "SFTP not connected. Use 'sftp-start' first."
        }
        
        let contents = sftp.contents(ofDirectory: path)
        
        if contents.isEmpty {
            return "(empty directory)"
        }
        
        var output = ""
        for item in contents {
            let isDir = item.isDirectory
            let size = item.fileSize
            let name = item.filename
            let perms = item.permissions
            
            let permStr = String(format: "%o", perms)
            let typeChar = isDir ? "d" : "-"
            
            if isDir {
                output += "\(typeChar)\(permStr)  \(size.padding(toLength: 10, withPad: " ", startingAt: 0))  📁 \(name)/\n"
            } else {
                output += "\(typeChar)\(permStr)  \(size.padding(toLength: 10, withPad: " ", startingAt: 0))  📄 \(name)\n"
            }
        }
        
        return output.trimmingCharacters(in: .newlines)
    }
    
    /// 上传文件
    func uploadFile(localPath: String, remotePath: String) async -> String {
        guard let sftp = sftpSession else {
            return "SFTP not connected. Use 'sftp-start' first."
        }
        
        let fileURL = URL(fileURLWithPath: localPath)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let success = sftp.writeContents(data, toFileAtPath: remotePath)
            
            if success {
                return "Uploaded: \(localPath) -> \(remotePath)"
            } else {
                return "Failed to upload file"
            }
        } catch {
            return "Error reading local file: \(error.localizedDescription)"
        }
    }
    
    /// 下载文件
    func downloadFile(remotePath: String, localPath: String) async -> String {
        guard let sftp = sftpSession else {
            return "SFTP not connected. Use 'sftp-start' first."
        }
        
        if let data = sftp.contents(atPath: remotePath) {
            do {
                try data.write(to: URL(fileURLWithPath: localPath))
                return "Downloaded: \(remotePath) -> \(localPath)"
            } catch {
                return "Error writing local file: \(error.localizedDescription)"
            }
        } else {
            return "Failed to download file"
        }
    }
    
    /// 创建远程目录
    func createRemoteDirectory(_ path: String) async -> String {
        guard let sftp = sftpSession else {
            return "SFTP not connected. Use 'sftp-start' first."
        }
        
        if sftp.createDirectory(atPath: path) {
            return "Created directory: \(path)"
        } else {
            return "Failed to create directory: \(path)"
        }
    }
    
    /// 删除远程文件
    func deleteRemoteFile(_ path: String) async -> String {
        guard let sftp = sftpSession else {
            return "SFTP not connected. Use 'sftp-start' first."
        }
        
        if sftp.removeFile(atPath: path) {
            return "Deleted: \(path)"
        } else {
            return "Failed to delete: \(path)"
        }
    }
    
    /// 获取连接信息
    func getConnectionInfo() -> String {
        guard isConnected else {
            return "Not connected"
        }
        return "\(username)@\(host):\(port)"
    }
    
    /// 解析 SSH 连接字符串
    /// - Parameter input: 格式如 "ssh root@124.221.35.221" 或 "ssh root@124.221.35.221 -p 2222"
    /// - Returns: 解析结果 (host, port, username)
    static func parseSSHCommand(_ input: String) -> (host: String, port: Int, username: String)? {
        let parts = input.split(separator: " ").map { String($0) }
        
        guard parts.count >= 2 else { return nil }
        
        // 解析 user@host 格式
        let userHost = parts[1]
        let userHostParts = userHost.split(separator: "@")
        
        guard userHostParts.count == 2 else { return nil }
        
        let username = String(userHostParts[0])
        let host = String(userHostParts[1])
        var port = 22
        
        // 检查是否有 -p 参数指定端口
        if let portIndex = parts.firstIndex(of: "-p"), portIndex + 1 < parts.count {
            port = Int(parts[portIndex + 1]) ?? 22
        }
        
        return (host, port, username)
    }
    
    // MARK: - Host Key Fingerprint
    
    /// 获取服务器指纹
    func getServerFingerprint() -> String? {
        guard let session = session else { return nil }
        return session.fingerprint()
    }
    
    /// 获取服务器公钥
    func getServerPublicKey() -> String? {
        guard let session = session else { return nil }
        return session.publicKey()
    }
}

// MARK: - Convenience Extensions

extension SSHService {
    
    /// 执行多个命令
    func executeCommands(_ commands: [String]) async -> [String] {
        var results: [String] = []
        for cmd in commands {
            let result = await executeCommand(cmd)
            results.append(result)
        }
        return results
    }
    
    /// 检查是否在 Shell 模式
    var isShellActive: Bool {
        return shellChannel != nil && shellChannel!.isShell
    }
    
    /// 获取当前工作目录（远程）
    func getCurrentRemoteDirectory() async -> String {
        return await executeCommand("pwd")
    }
}
