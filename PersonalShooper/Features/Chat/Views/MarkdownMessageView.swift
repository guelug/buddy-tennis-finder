import SwiftUI

/// Renders markdown-style text with proper paragraph spacing, headings, and lists.
/// Replaces AttributedString markdown which doesn't handle line breaks well.
struct MarkdownMessageView: View {
    let text: String
    let isUser: Bool
    var textSelectionEnabled: Bool = false

    /// Parsed blocks from the markdown text
    private var blocks: [MarkdownBlock] {
        parseMarkdown(text)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block)
                    .id("block-\(index)")
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading1(let content):
            Text(content)
                .font(.title2.weight(.bold))
                .foregroundStyle(isUser ? .white : .primary)

        case .heading2(let content):
            Text(content)
                .font(.title3.weight(.semibold))
                .foregroundStyle(isUser ? .white : .primary)

        case .heading3(let content):
            Text(content)
                .font(.headline.weight(.semibold))
                .foregroundStyle(isUser ? .white : .primary)

        case .bulletList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                        Text(parseInlineStyles(item))
                            .font(.body)
                            .foregroundStyle(isUser ? .white : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .id("bullet-\(index)")
                }
            }

        case .numberedList(let items):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 6) {
                        Text("\(index + 1).")
                            .font(.body)
                            .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                        Text(parseInlineStyles(item))
                            .font(.body)
                            .foregroundStyle(isUser ? .white : .primary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .id("numbered-\(index)")
                }
            }

        case .codeBlock(let code):
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(isUser ? Color.white.opacity(0.15) : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(isUser ? .white : .primary)

        case .paragraph(let content):
            if textSelectionEnabled {
                Text(parseInlineStyles(content))
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
            } else {
                Text(parseInlineStyles(content))
                    .font(.body)
                    .foregroundStyle(isUser ? .white : .primary)
            }
        }
    }

    /// Parse inline styles: **bold**, *italic*, `code`
    private func parseInlineStyles(_ text: String) -> AttributedString {
        var result = text

        // Replace **bold** with attributed markers (we'll use a simpler approach)
        // Since AttributedString markdown inline is tricky, we'll do basic replacements
        // and return a plain string for now - bold will be handled by regex replacement

        // First, try AttributedString with inline markdown
        if let attributed = try? AttributedString(
            markdown: result,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnly,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return attributed
        }

        // Fallback: return as-is
        return AttributedString(result)
    }
}

// MARK: - Markdown Parsing

private enum MarkdownBlock: Equatable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case bulletList([String])
    case numberedList([String])
    case codeBlock(String)
    case paragraph(String)
}

private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
    let lines = text.components(separatedBy: .newlines)
    var blocks: [MarkdownBlock] = []
    var currentParagraph = ""
    var currentBulletItems: [String] = []
    var currentNumberedItems: [String] = []
    var inCodeBlock = false
    var codeBlockContent = ""

    func flushParagraph() {
        let trimmed = currentParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            blocks.append(.paragraph(trimmed))
        }
        currentParagraph = ""
    }

    func flushBullets() {
        if !currentBulletItems.isEmpty {
            blocks.append(.bulletList(currentBulletItems))
            currentBulletItems = []
        }
    }

    func flushNumbered() {
        if !currentNumberedItems.isEmpty {
            blocks.append(.numberedList(currentNumberedItems))
            currentNumberedItems = []
        }
    }

    for line in lines {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Code blocks
        if trimmed.hasPrefix("```") {
            if inCodeBlock {
                // End code block
                blocks.append(.codeBlock(codeBlockContent.trimmingCharacters(in: .newlines)))
                codeBlockContent = ""
                inCodeBlock = false
            } else {
                // Start code block
                flushParagraph()
                flushBullets()
                flushNumbered()
                inCodeBlock = true
            }
            continue
        }

        if inCodeBlock {
            codeBlockContent += line + "\n"
            continue
        }

        // Empty line = paragraph break
        if trimmed.isEmpty {
            flushParagraph()
            flushBullets()
            flushNumbered()
            continue
        }

        // Headings
        if trimmed.hasPrefix("# ") {
            flushParagraph()
            flushBullets()
            flushNumbered()
            blocks.append(.heading1(String(trimmed.dropFirst(2))))
            continue
        }
        if trimmed.hasPrefix("## ") {
            flushParagraph()
            flushBullets()
            flushNumbered()
            blocks.append(.heading2(String(trimmed.dropFirst(3))))
            continue
        }
        if trimmed.hasPrefix("### ") {
            flushParagraph()
            flushBullets()
            flushNumbered()
            blocks.append(.heading3(String(trimmed.dropFirst(4))))
            continue
        }

        // Bullet list
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            flushParagraph()
            flushNumbered()
            let item = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
            currentBulletItems.append(item)
            continue
        }

        // Numbered list
        if let match = trimmed.firstMatch(of: /^\d+\.\s+(.+)$/) {
            flushParagraph()
            flushBullets()
            let item = String(match.output.1)
            currentNumberedItems.append(item)
            continue
        }

        // Continue previous list item if indented
        if !currentBulletItems.isEmpty && line.hasPrefix("  ") {
            let lastIndex = currentBulletItems.count - 1
            currentBulletItems[lastIndex] += " " + trimmed
            continue
        }
        if !currentNumberedItems.isEmpty && line.hasPrefix("  ") {
            let lastIndex = currentNumberedItems.count - 1
            currentNumberedItems[lastIndex] += " " + trimmed
            continue
        }

        // Regular paragraph line
        flushBullets()
        flushNumbered()
        if currentParagraph.isEmpty {
            currentParagraph = trimmed
        } else {
            currentParagraph += " " + trimmed
        }
    }

    // Flush remaining
    flushParagraph()
    flushBullets()
    flushNumbered()

    if inCodeBlock && !codeBlockContent.isEmpty {
        blocks.append(.codeBlock(codeBlockContent.trimmingCharacters(in: .newlines)))
    }

    return blocks
}
