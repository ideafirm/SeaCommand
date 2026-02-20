//
//  ContentView.swift
//  demo
//
//  Created by sealua on 2026/2/17.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TerminalViewModel()
    @FocusState private var isInputFocused: Bool
    @State private var scrollProxy: ScrollViewProxy?
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // 状态栏
                if !viewModel.sshStatus.isEmpty {
                    HStack {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text(viewModel.sshStatus)
                            .font(.custom("Menlo", size: 12))
                            .foregroundColor(Color(hex: "00FF00"))
                        Spacer()
                        if viewModel.isShellMode {
                            Text("[SHELL MODE]")
                                .font(.custom("Menlo", size: 12))
                                .foregroundColor(Color(hex: "FFD700"))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "1A1A1A"))
                }
                
                // 输出区域
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(viewModel.lines) { line in
                                Text(line.displayContent)
                                    .font(.custom("Menlo", size: 14))
                                    .foregroundColor(line.color)
                                    .textSelection(.enabled)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 2)
                            }
                            // 底部锚点
                            Color.clear
                                .frame(height: 1)
                                .id("bottom")
                        }
                        .padding(.top, 8)
                    }
                    .background(Color.black)
                    .onChange(of: viewModel.lines.count) { _ in
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                    .onChange(of: viewModel.lines.first?.content) { _ in
                        // 当 Shell 模式下内容更新时滚动
                        if viewModel.isShellMode {
                            withAnimation(.easeOut(duration: 0.1)) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                        }
                    }
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
                
                // 分隔线
                Rectangle()
                    .fill(Color(hex: "00FF00").opacity(0.3))
                    .frame(height: 1)
                
                // Shell 模式特殊键栏
                if viewModel.isShellMode {
                    HStack(spacing: 12) {
                        SpecialKeyButton(title: "Ctrl+C", action: { viewModel.sendSpecialKey("ctrl-c") })
                        SpecialKeyButton(title: "Ctrl+D", action: { viewModel.sendSpecialKey("ctrl-d") })
                        SpecialKeyButton(title: "Ctrl+Z", action: { viewModel.sendSpecialKey("ctrl-z") })
                        SpecialKeyButton(title: "Tab", action: { viewModel.sendSpecialKey("tab") })
                        Spacer()
                        SpecialKeyButton(title: "Exit Shell", action: { viewModel.sendSpecialKey("ctrl-d"); viewModel.executeCommand() }, isDestructive: true)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "1A1A1A"))
                }
                
                // 输入区域
                HStack(spacing: 0) {
                    // 提示符
                    Text(viewModel.isShellMode ? "$" : ">")
                        .font(.custom("Menlo", size: 16))
                        .foregroundColor(Color(hex: "00FF00"))
                        .padding(.leading, 12)
                    
                    // 输入框
                    TextField(viewModel.isShellMode ? "Remote command..." : "Enter command...", text: $viewModel.currentInput)
                        .font(.custom("Menlo", size: 14))
                        .foregroundColor(.white)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .focused($isInputFocused)
                        .onSubmit {
                            viewModel.executeCommand()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 8)
                    
                    // 运行按钮
                    Button(action: {
                        viewModel.executeCommand()
                    }) {
                        Image(systemName: viewModel.isExecuting ? "hourglass" : "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(viewModel.isExecuting ? Color.gray : Color(hex: "00FF00"))
                    }
                    .disabled(viewModel.isExecuting)
                    .padding(.trailing, 12)
                }
                .background(Color(hex: "0D0D0D"))
                .overlay(
                    RoundedRectangle(cornerRadius: 0)
                        .stroke(Color(hex: "00FF00").opacity(0.5), lineWidth: 1)
                )
            }
            .background(Color.black)
            .ignoresSafeArea(.keyboard)
            .onTapGesture {
                isInputFocused = true
            }
            .onAppear {
                isInputFocused = true
            }
            .alert("SSH Connection", isPresented: .constant(false)) {
                Button("OK", role: .cancel) { }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Special Key Button
struct SpecialKeyButton: View {
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Menlo", size: 12))
                .foregroundColor(isDestructive ? .red : Color(hex: "00FF00"))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(hex: "2A2A2A"))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isDestructive ? Color.red.opacity(0.5) : Color(hex: "00FF00").opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - 键盘命令处理 View Modifier
struct KeyboardHandlingView: ViewModifier {
    @Binding var viewModel: TerminalViewModel
    
    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                // 键盘显示时的处理
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
