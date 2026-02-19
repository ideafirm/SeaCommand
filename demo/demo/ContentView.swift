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
                    .onAppear {
                        scrollProxy = proxy
                    }
                }
                
                // 分隔线
                Rectangle()
                    .fill(Color(hex: "00FF00").opacity(0.3))
                    .frame(height: 1)
                
                // 输入区域
                HStack(spacing: 0) {
                    // 提示符
                    Text(">")
                        .font(.custom("Menlo", size: 16))
                        .foregroundColor(Color(hex: "00FF00"))
                        .padding(.leading, 12)
                    
                    // 输入框
                    TextField("", text: $viewModel.currentInput)
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
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(hex: "00FF00"))
                    }
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
        }
        .preferredColorScheme(.dark)
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
