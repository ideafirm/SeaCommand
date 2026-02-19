//
//  TerminalLine.swift
//  demo
//
//  Created by sealua on 2026/2/18.
//

import SwiftUI

/// 终端输出行的类型
enum TerminalLineType {
    case input       // 用户输入的命令
    case output      // 命令输出结果
    case error       // 错误信息
    case system      // 系统信息（欢迎信息等）
}

/// 终端输出行模型
struct TerminalLine: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let type: TerminalLineType
    let timestamp = Date()
    
    /// 根据类型返回对应的颜色
    var color: Color {
        switch type {
        case .input:
            return Color(hex: "00FF00") // 亮绿色
        case .output:
            return Color(hex: "FFFFFF") // 白色
        case .error:
            return Color(hex: "FF6B6B") // 红色
        case .system:
            return Color(hex: "4ECDC4") // 青色
        }
    }
    
    /// 格式化显示内容
    var displayContent: String {
        switch type {
        case .input:
            return "> \(content)"
        default:
            return content
        }
    }
    
    static func == (lhs: TerminalLine, rhs: TerminalLine) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Color Extension for Hex Support
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
