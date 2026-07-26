import SwiftUI

enum MPTheme {
    static let background = Color(red: 0.027, green: 0.047, blue: 0.031)
    static let surface = Color(red: 0.071, green: 0.102, blue: 0.075)
    static let accent = Color(red: 0.776, green: 0.945, blue: 0.208)
    static let muted = Color.white.opacity(0.62)
}

struct MPCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    var body: some View {
        content.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(MPTheme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08)))
    }
}
