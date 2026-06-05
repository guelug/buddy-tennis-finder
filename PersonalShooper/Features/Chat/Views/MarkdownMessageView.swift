import SwiftUI

/// Renders markdown-style text with proper paragraph spacing, headings, lists, **tables**,
/// fenced **code snippets** (with language label + horizontal scroll), blockquotes and rules.
/// Replaces raw AttributedString markdown, which doesn't handle block layout or line breaks well.
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
            Text(parseInlineStyles(content))
                .font(.title2.weight(.bold))
                .foregroundStyle(isUser ? .white : .primary)

        case .heading2(let content):
            Text(parseInlineStyles(content))
                .font(.title3.weight(.semibold))
                .foregroundStyle(isUser ? .white : .primary)

        case .heading3(let content):
            Text(parseInlineStyles(content))
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
                            .font(.body.monospacedDigit())
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

        case .codeBlock(let code, let language):
            codeBlockView(code: code, language: language)

        case .table(let headers, let rows):
            tableView(headers: headers, rows: rows)

        case .blockquote(let content):
            HStack(alignment: .top, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(isUser ? Color.white.opacity(0.5) : Theme.Colors.primary.opacity(0.6))
                    .frame(width: 3)
                Text(parseInlineStyles(content))
                    .font(.body.italic())
                    .foregroundStyle(isUser ? .white.opacity(0.95) : .secondary)
                    .multilineTextAlignment(.leading)
            }
            .fixedSize(horizontal: false, vertical: true)

        case .divider:
            Divider()
                .overlay(isUser ? Color.white.opacity(0.3) : Color(.separator))

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

    // MARK: - Code snippet

    @ViewBuilder
    private func codeBlockView(code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.semibold))
                    .foregroundStyle(isUser ? .white.opacity(0.7) : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(isUser ? Color.white.opacity(0.12) : Color(.systemGray5))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(isUser ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(10)
            }
        }
        .background(isUser ? Color.white.opacity(0.15) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isUser ? Color.white.opacity(0.15) : Color(.separator).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Table

    @ViewBuilder
    private func tableView(headers: [String], rows: [[String]]) -> some View {
        let columnCount = max(headers.count, rows.map(\.count).max() ?? 0)

        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    ForEach(0..<columnCount, id: \.self) { col in
                        Text(parseInlineStyles(col < headers.count ? headers[col] : ""))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isUser ? .white : .primary)
                    }
                }

                Divider()
                    .overlay(isUser ? Color.white.opacity(0.3) : Color(.separator))
                    .gridCellColumns(columnCount)

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(0..<columnCount, id: \.self) { col in
                            Text(parseInlineStyles(col < row.count ? row[col] : ""))
                                .font(.callout)
                                .foregroundStyle(isUser ? .white.opacity(0.95) : .primary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(isUser ? Color.white.opacity(0.1) : Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isUser ? Color.white.opacity(0.15) : Color(.separator).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Inline styles

    /// Parse inline styles: **bold**, *italic*, `code`, [links](url) via AttributedString markdown.
    private func parseInlineStyles(_ text: String) -> AttributedString {
        if let attributed = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                interpretedSyntax: .inlineOnlyPreservingWhitespace,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            return attributed
        }
        return AttributedString(text)
    }
}

// MARK: - Markdown Parsing

private enum MarkdownBlock: Equatable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case bulletList([String])
    case numberedList([String])
    case codeBlock(String, String?)
    case table([String], [[String]])
    case blockquote(String)
    case divider
    case paragraph(String)
}

/// Splits a markdown table row `| a | b |` into trimmed cells. Returns nil if it isn't pipe-delimited.
private func parseTableRow(_ line: String) -> [String]? {
    var trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.contains("|") else { return nil }
    if trimmed.hasPrefix("|") { trimmed.removeFirst() }
    if trimmed.hasSuffix("|") { trimmed.removeLast() }
    return trimmed.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
}

/// True for a GFM separator row like `|---|:--:|`.
private func isTableSeparator(_ line: String) -> Bool {
    guard let cells = parseTableRow(line), !cells.isEmpty else { return false }
    return cells.allSatisfy { cell in
        let compact = cell.replacingOccurrences(of: " ", with: "")
        return !compact.isEmpty && compact.contains("-") && compact.allSatisfy { $0 == "-" || $0 == ":" }
    }
}

/// True for a horizontal rule line (`---`, `***`, `___`).
private func isHorizontalRule(_ line: String) -> Bool {
    let compact = line.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: " ", with: "")
    guard compact.count >= 3 else { return false }
    return compact.allSatisfy { $0 == "-" } || compact.allSatisfy { $0 == "*" } || compact.allSatisfy { $0 == "_" }
}

private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
    let lines = text.components(separatedBy: .newlines)
    var blocks: [MarkdownBlock] = []
    var currentParagraph = ""
    var currentBulletItems: [String] = []
    var currentNumberedItems: [String] = []

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

    func flushAll() {
        flushParagraph()
        flushBullets()
        flushNumbered()
    }

    var i = 0
    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Fenced code block (capture optional language after the opening fence).
        if trimmed.hasPrefix("```") {
            flushAll()
            let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            var codeLines: [String] = []
            i += 1
            while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                codeLines.append(lines[i])
                i += 1
            }
            // Skip the closing fence if present.
            if i < lines.count { i += 1 }
            blocks.append(.codeBlock(codeLines.joined(separator: "\n"), language.isEmpty ? nil : language))
            continue
        }

        // GFM table: a header row followed by a separator row.
        if let headers = parseTableRow(line),
           i + 1 < lines.count,
           isTableSeparator(lines[i + 1]) {
            flushAll()
            var rows: [[String]] = []
            var j = i + 2
            while j < lines.count {
                let candidate = lines[j]
                guard candidate.contains("|"),
                      !candidate.trimmingCharacters(in: .whitespaces).isEmpty,
                      !isTableSeparator(candidate),
                      let cells = parseTableRow(candidate) else { break }
                rows.append(cells)
                j += 1
            }
            blocks.append(.table(headers, rows))
            i = j
            continue
        }

        // Horizontal rule.
        if isHorizontalRule(trimmed) {
            flushAll()
            blocks.append(.divider)
            i += 1
            continue
        }

        // Blank line ends the current block group.
        if trimmed.isEmpty {
            flushAll()
            i += 1
            continue
        }

        // Headings.
        if trimmed.hasPrefix("### ") {
            flushAll()
            blocks.append(.heading3(String(trimmed.dropFirst(4))))
            i += 1
            continue
        }
        if trimmed.hasPrefix("## ") {
            flushAll()
            blocks.append(.heading2(String(trimmed.dropFirst(3))))
            i += 1
            continue
        }
        if trimmed.hasPrefix("# ") {
            flushAll()
            blocks.append(.heading1(String(trimmed.dropFirst(2))))
            i += 1
            continue
        }

        // Blockquote.
        if trimmed.hasPrefix(">") {
            flushAll()
            let content = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            blocks.append(.blockquote(content))
            i += 1
            continue
        }

        // Bullet list.
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            flushParagraph()
            flushNumbered()
            currentBulletItems.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            i += 1
            continue
        }

        // Numbered list.
        if let match = trimmed.firstMatch(of: /^\d+\.\s+(.+)$/) {
            flushParagraph()
            flushBullets()
            currentNumberedItems.append(String(match.output.1))
            i += 1
            continue
        }

        // Continuation of the last list item when the line is indented.
        if !currentBulletItems.isEmpty && line.hasPrefix("  ") {
            currentBulletItems[currentBulletItems.count - 1] += " " + trimmed
            i += 1
            continue
        }
        if !currentNumberedItems.isEmpty && line.hasPrefix("  ") {
            currentNumberedItems[currentNumberedItems.count - 1] += " " + trimmed
            i += 1
            continue
        }

        // Regular paragraph text.
        flushBullets()
        flushNumbered()
        currentParagraph += currentParagraph.isEmpty ? trimmed : " " + trimmed
        i += 1
    }

    flushAll()
    return blocks
}
