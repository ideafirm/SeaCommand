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

/// SSH 服务 - 存根实现（SSH 功能不可用）
class SSHService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = SSHService()
    
    // MARK: - Published Properties
    @Published var connectionState: SSHConnectionState = .disconnected
    @Published var output: String = ""
    @Published var isConnected: Bool = false
    
    // MARK: - Private Properties
    private var host: String = ""
    private var port: Int = 22
    private var username: String = ""
    
    // Shell 输出回调
    var shellOutputHandler: ((String) -> Void)?
    var shellErrorHandler: ((String) -> Void)?
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Methods
    
    private func unavailableMessage() -> String {
        return "SSH functionality is not available in this build."
    }
    
    /// 连接到 SSH 服务器
    func connect(host: String, port: Int = 22, username: String, password: String) async -> String {
        return unavailableMessage()
    }
    
    /// 使用私钥连接
    func connectWithKey(host: String, port: Int = 22, username: String, privateKey: String, passphrase: String? = nil) async -> String {
        return unavailableMessage()
    }
    
    /// 断开 SSH 连接
    func disconnect() {
        host = ""
        username = ""
        connectionState = .disconnected
        isConnected = false
        output = ""
    }
    
    /// 在远程服务器执行命令
    func executeCommand(_ command: String) async -> String {
        return unavailableMessage()
    }
    
    /// 执行命令并返回实时输出
    func executeCommandWithOutput(_ command: String, outputHandler: @escaping (String) -> Void) async -> String {
        let msg = unavailableMessage()
        outputHandler(msg)
        return msg
    }
    
    // MARK: - Interactive Shell
    
    /// 启动交互式 Shell 会话
    func startShell() async -> Bool {
        return false
    }
    
    /// 关闭 Shell 会话
    func closeShell() {}
    
    /// 向 Shell 发送数据
    func writeToShell(_ data: String) {}
    
    /// 发送终端大小变化
    func resizeTerminal(width: Int, height: Int) {}
    
    // MARK: - SFTP Operations
    
    /// 初始化 SFTP 会话
    func startSFTP() async -> String {
        return unavailableMessage()
    }
    
    /// 列出远程目录
    func listRemoteDirectory(_ path: String = ".") async -> String {
        return unavailableMessage()
    }
    
    /// 上传文件
    func uploadFile(localPath: String, remotePath: String) async -> String {
        return unavailableMessage()
    }
    
    /// 下载文件
    func downloadFile(remotePath: String, localPath: String) async -> String {
        return unavailableMessage()
    }
    
    /// 创建远程目录
    func createRemoteDirectory(_ path: String) async -> String {
        return unavailableMessage()
    }
    
    /// 删除远程文件
    func deleteRemoteFile(_ path: String) async -> String {
        return unavailableMessage()
    }
    
    /// 获取连接信息
    func getConnectionInfo() -> String {
        guard isConnected else {
            return "Not connected"
        }
        return "\(username)@\(host):\(port)"
    }
    
    /// 解析 SSH 连接字符串
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
        return nil
    }
    
    /// 获取服务器公钥
    func getServerPublicKey() -> String? {
        return nil
    }
}

// MARK: - Convenience Extensions

extension SSHService {
    
    /// 执行多个命令
    func executeCommands(_ commands: [String]) async -> [String] {
        return commands.map { _ in unavailableMessage() }
    }
    
    /// 检查是否在 Shell 模式
    var isShellActive: Bool {
        return false
    }
    
    /// 获取当前工作目录（远程）
    func getCurrentRemoteDirectory() async -> String {
        return unavailableMessage()
    }
}
