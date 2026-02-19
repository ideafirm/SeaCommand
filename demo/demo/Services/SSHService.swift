//
//  SSHService.swift
//  demo
//
//  Created by sealua on 2026/2/19.
//

import Foundation
import Combine

/// SSH 连接状态
enum SSHConnectionState {
    case disconnected
    case connecting
    case connected
    case error(String)
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
    private var session: AnyObject?
    private var host: String = ""
    private var port: Int = 22
    private var username: String = ""
    private var password: String = ""
    private var outputQueue = DispatchQueue(label: "com.demo.ssh.output")
    
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
        
        // 模拟连接过程
        // 注意：实际 SSH 实现需要使用 Shout 或其他 SSH 库
        // 这里提供基础的连接框架
        
        do {
            // 尝试建立 TCP 连接测试
            let connectionTest = await testConnection(host: host, port: port)
            
            if connectionTest {
                await MainActor.run {
                    self.connectionState = .connected
                    self.isConnected = true
                }
                return "Connected to \(username)@\(host):\(port)"
            } else {
                await MainActor.run {
                    self.connectionState = .error("Connection refused")
                    self.isConnected = false
                }
                return "ssh: connect to host \(host) port \(port): Connection refused"
            }
        }
    }
    
    /// 测试 TCP 连接
    private func testConnection(host: String, port: Int) async -> Bool {
        return await withCheckedContinuation { continuation in
            let queue = DispatchQueue.global()
            queue.async {
                let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
                if socket < 0 {
                    continuation.resume(returning: false)
                    return
                }
                
                defer {
                    close(socket)
                }
                
                var timeout = timeval(tv_sec: 5, tv_usec: 0)
                setsockopt(socket, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                setsockopt(socket, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))
                
                var addr = sockaddr_in()
                addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
                addr.sin_family = sa_family_t(AF_INET)
                addr.sin_port = in_port_t(port).bigEndian
                
                if inet_pton(AF_INET, host, &addr.sin_addr) <= 0 {
                    // 尝试 DNS 解析
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
    
    /// 断开 SSH 连接
    func disconnect() {
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
        guard isConnected else {
            return "ssh: not connected to any host"
        }
        
        // 注意：实际命令执行需要 SSH 库支持
        // 这里返回提示信息
        return "[SSH Command Execution]\nHost: \(username)@\(host):\(port)\nCommand: \(command)\n\nNote: Full SSH command execution requires adding an SSH library (e.g., Shout).\nUse 'ssh add-package' for instructions."
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
}
