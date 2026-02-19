//
//  TerminalViewModel.swift
//  demo
//
//  Created by sealua on 2026/2/18.
//

import SwiftUI

/// 终端视图模型
class TerminalViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var lines: [TerminalLine] = []
    @Published var currentInput: String = ""
    @Published var commandHistory: [String] = []
    @Published var historyIndex: Int = -1
    @Published var isExecuting: Bool = false
    @Published var sshStatus: String = ""
    @Published var isShellMode: Bool = false
    
    // MARK: - Private Properties
    private let commandService = CommandService.shared
    private let sshService = SSHService.shared
    private var pendingSSHParams: (host: String, port: Int, username: String)?
    
    // MARK: - Initialization
    init() {
        showWelcome()
        setupSSHHandlers()
    }
    
    // MARK: - Public Methods
    
    /// 设置 SSH 输出处理
    private func setupSSHHandlers() {
        sshService.shellOutputHandler = { [weak self] output in
            guard let self = self else { return }
            Task { @MainActor in
                if self.isShellMode {
                    self.appendRawOutput(output)
                }
            }
        }
        
        sshService.shellErrorHandler = { [weak self] error in
            guard let self = self else { return }
            Task { @MainActor in
                self.addLine(content: error, type: .error)
            }
        }
    }
    
    /// 追加原始输出（用于 Shell 模式）
    private func appendRawOutput(_ output: String) {
        if let lastLine = lines.last, lastLine.type == .output {
            // 追加到最后一行
            lastLine.content += output
        } else {
            let newLine = TerminalLine(content: output, type: .output)
            lines.append(newLine)
        }
    }
    
    /// 执行当前输入的命令
    func executeCommand() {
        let input = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !input.isEmpty else { return }
        
        // Shell 模式：直接发送到远程
        if isShellMode {
            handleShellInput(input)
            return
        }
        
        // 添加输入行
        addLine(content: input, type: .input)
        
        // 添加到历史记录
        if !input.isEmpty && (commandHistory.isEmpty || commandHistory.last != input) {
            commandHistory.append(input)
        }
        historyIndex = commandHistory.count
        
        // 清空当前输入
        currentInput = ""
        
        // 处理 SSH 登录命令
        if input.hasPrefix("ssh-login ") {
            handleSSHLogin(input)
            return
        }
        
        // 处理 curl-async 命令
        if input.hasPrefix("curl-async ") {
            handleCurlAsync(input)
            return
        }
        
        // 处理 ping-async 命令
        if input.hasPrefix("ping-async ") {
            handlePingAsync(input)
            return
        }
        
        // 处理 SSH 连接命令，保存参数
        if input.hasPrefix("ssh ") && !sshService.isConnected {
            if let params = SSHService.parseSSHCommand(input) {
                pendingSSHParams = params
            }
        }
        
        // 处理 ssh-shell 进入 Shell 模式
        if input == "ssh-shell" {
            handleSSHShell()
            return
        }
        
        // 处理 ssh-shell-end 退出 Shell 模式
        if input == "ssh-shell-end" {
            handleSSHShellEnd()
            return
        }
        
        // 检查是否为异步命令
        if commandService.executeAsync(input, outputHandler: { [weak self] output, isError in
            self?.addLine(content: output, type: isError ? .error : .output)
        }, completionHandler: { [weak self] in
            self?.isExecuting = false
        }) {
            isExecuting = true
            return
        }
        
        // 执行同步命令
        let result = commandService.execute(input)
        
        // 处理特殊命令
        if result.output == "__CLEAR__" {
            clearTerminal()
        } else if !result.output.isEmpty {
            addLine(content: result.output, type: result.isError ? .error : .output)
        }
        
        // 更新 SSH 状态
        updateSSHStatus()
    }
    
    /// 处理 Shell 模式下的输入
    private func handleShellInput(_ input: String) {
        // 检查退出命令
        if input == "exit" || input == "logout" || input == "ssh-shell-end" {
            handleSSHShellEnd()
            return
        }
        
        // 检查 Ctrl+C (用 ctrl-c 命令代替)
        if input == "ctrl-c" {
            sshService.writeToShell("\u{03}")
            currentInput = ""
            return
        }
        
        // 检查 Ctrl+D
        if input == "ctrl-d" {
            sshService.writeToShell("\u{04}")
            currentInput = ""
            return
        }
        
        // 发送命令到远程 Shell
        sshService.writeToShell(input + "\n")
        currentInput = ""
    }
    
    /// 浏览上一条历史命令
    func navigateHistoryUp() {
        guard !commandHistory.isEmpty else { return }
        
        if historyIndex > 0 {
            historyIndex -= 1
            currentInput = commandHistory[historyIndex]
        } else if historyIndex == 0 {
            // 已经在第一条，保持不变
            currentInput = commandHistory[0]
        }
    }
    
    /// 浏览下一条历史命令
    func navigateHistoryDown() {
        guard !commandHistory.isEmpty else { return }
        
        if historyIndex < commandHistory.count - 1 {
            historyIndex += 1
            currentInput = commandHistory[historyIndex]
        } else {
            historyIndex = commandHistory.count
            currentInput = ""
        }
    }
    
    /// 清空终端
    func clearTerminal() {
        lines = []
        showWelcome()
    }
    
    /// 发送特殊键
    func sendSpecialKey(_ key: String) {
        if isShellMode {
            switch key {
            case "ctrl-c":
                sshService.writeToShell("\u{03}")
            case "ctrl-d":
                sshService.writeToShell("\u{04}")
            case "ctrl-z":
                sshService.writeToShell("\u{1A}")
            case "tab":
                sshService.writeToShell("\t")
            case "enter":
                sshService.writeToShell("\n")
            default:
                break
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// 添加一行输出
    private func addLine(content: String, type: TerminalLineType) {
        withAnimation(.easeInOut(duration: 0.1)) {
            lines.append(TerminalLine(content: content, type: type))
        }
    }
    
    /// 显示欢迎信息
    private func showWelcome() {
        let welcome = """
        ╔════════════════════════════════════════════╗
        ║     Welcome to iOS Terminal v2.0          ║
        ║     Full SSH Support Enabled              ║
        ║     Type 'help' for available commands    ║
        ╚════════════════════════════════════════════╝
        """
        addLine(content: welcome, type: .system)
        addLine(content: "Working directory: \(commandService.documentsDirectory.path)", type: .system)
        addLine(content: "", type: .system)
    }
    
    /// 更新 SSH 状态显示
    private func updateSSHStatus() {
        if sshService.isConnected {
            var status = "[SSH: \(sshService.getConnectionInfo())"
            if isShellMode {
                status += " | SHELL"
            }
            status += "]"
            sshStatus = status
        } else {
            sshStatus = ""
            isShellMode = false
        }
    }
    
    /// 处理 SSH 登录
    private func handleSSHLogin(_ input: String) {
        let parts = input.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            addLine(content: "ssh-login: missing password", type: .error)
            return
        }
        
        let password = parts.dropFirst().joined(separator: " ")
        
        // 检查是否有待连接的 SSH 参数
        guard let params = pendingSSHParams else {
            addLine(content: "ssh-login: no pending SSH connection. Use 'ssh user@host' first.", type: .error)
            return
        }
        
        isExecuting = true
        addLine(content: "Authenticating...", type: .system)
        
        Task {
            let result = await sshService.connect(
                host: params.host,
                port: params.port,
                username: params.username,
                password: password
            )
            
            await MainActor.run {
                addLine(content: result, type: result.contains("failed") || result.contains("refused") || result.contains("Error") ? .error : .output)
                isExecuting = false
                updateSSHStatus()
                
                if sshService.isConnected {
                    pendingSSHParams = nil
                    addLine(content: "", type: .system)
                    addLine(content: "Use 'ssh-exec <command>' to execute remote commands.", type: .system)
                    addLine(content: "Use 'ssh-shell' to start interactive shell.", type: .system)
                }
            }
        }
    }
    
    /// 启动 SSH Shell 模式
    private func handleSSHShell() {
        guard sshService.isConnected else {
            addLine(content: "ssh-shell: not connected. Connect first with 'ssh user@host' and 'ssh-login'.", type: .error)
            return
        }
        
        isExecuting = true
        addLine(content: "Starting interactive shell...", type: .system)
        
        Task {
            let success = await sshService.startShell()
            
            await MainActor.run {
                if success {
                    isShellMode = true
                    addLine(content: "Interactive shell started.", type: .system)
                    addLine(content: "Type 'exit', 'logout', or 'ssh-shell-end' to exit shell mode.", type: .system)
                    addLine(content: "Use 'ctrl-c', 'ctrl-d', 'ctrl-z', 'tab' for special keys.", type: .system)
                } else {
                    addLine(content: "Failed to start interactive shell.", type: .error)
                }
                isExecuting = false
                updateSSHStatus()
            }
        }
    }
    
    /// 结束 SSH Shell 模式
    private func handleSSHShellEnd() {
        sshService.closeShell()
        isShellMode = false
        addLine(content: "Interactive shell ended.", type: .system)
        updateSSHStatus()
    }
    
    /// 处理 curl 异步请求
    private func handleCurlAsync(_ input: String) {
        let parts = input.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2, let url = URL(string: String(parts[1])) else {
            addLine(content: "curl-async: invalid URL", type: .error)
            return
        }
        
        isExecuting = true
        addLine(content: "Fetching \(url.absoluteString)...", type: .system)
        
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                
                if let httpResponse = response as? HTTPURLResponse {
                    let statusText = "HTTP \(httpResponse.statusCode)"
                    await MainActor.run {
                        addLine(content: statusText, type: .system)
                    }
                }
                
                if let responseString = String(data: data, encoding: .utf8) {
                    // 限制输出长度
                    let maxLines = 50
                    let lines = responseString.split(separator: "\n")
                    let output = lines.prefix(maxLines).joined(separator: "\n")
                    let truncated = lines.count > maxLines ? "\n... (truncated, \(lines.count - maxLines) more lines)" : ""
                    
                    await MainActor.run {
                        addLine(content: output + truncated, type: .output)
                        isExecuting = false
                    }
                } else {
                    await MainActor.run {
                        addLine(content: "Binary data (\(data.count) bytes)", type: .output)
                        isExecuting = false
                    }
                }
            } catch {
                await MainActor.run {
                    addLine(content: "curl: \(error.localizedDescription)", type: .error)
                    isExecuting = false
                }
            }
        }
    }
    
    /// 处理 ping 异步请求
    private func handlePingAsync(_ input: String) {
        let parts = input.split(separator: " ", omittingEmptySubsequences: true)
        guard parts.count >= 2 else {
            addLine(content: "ping-async: missing host", type: .error)
            return
        }
        
        let host = String(parts[1])
        isExecuting = true
        
        // 使用异步命令处理
        _ = commandService.executeAsync("ping \(host)", outputHandler: { [weak self] output, isError in
            self?.addLine(content: output, type: isError ? .error : .output)
        }, completionHandler: { [weak self] in
            self?.isExecuting = false
        })
    }
}
