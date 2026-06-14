import SwiftUI
import MapKit
import SwiftData

/// Renders markdown-style text with proper paragraph spacing, headings, lists, **tables**,
/// fenced **code snippets**, blockquotes, rules, checklists, closet item cards, maps and action buttons.
/// Replaces raw AttributedString markdown, which doesn't handle block layout or line breaks well.
struct MarkdownMessageView: View {
    let text: String
    let isUser: Bool
    var textSelectionEnabled: Bool = false

    @Environment(\.modelContext) private var modelContext

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
            bulletListView(items: items)

        case .numberedList(let items):
            numberedListView(items: items)

        case .checklist(let items):
            checklistView(items: items)

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

        case .closetItemCard(let itemID):
            closetItemCardView(itemID: itemID)

        case .map(let latitude, let longitude, let label):
            mapView(latitude: latitude, longitude: longitude, label: label)

        case .actionButton(let title, let actionID):
            actionButtonView(title: title, actionID: actionID)

        case .paragraph(let content):
            paragraphView(content: content)
        }
    }

    // MARK: - Lists

    private func bulletListView(items: [String]) -> some View {
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
    }

    private func numberedListView(items: [String]) -> some View {
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
    }

    // MARK: - Checklist

    private func checklistView(items: [CheckItem]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: item.isChecked ? "checkmark.square.fill" : "square")
                        .font(.body)
                        .foregroundStyle(isUser ? .white.opacity(0.9) : Theme.Colors.primary)
                    Text(parseInlineStyles(item.text))
                        .font(.body)
                        .foregroundStyle(isUser ? .white : .primary)
                        .multilineTextAlignment(.leading)
                        .strikethrough(item.isChecked, color: isUser ? .white.opacity(0.6) : .secondary)
                    Spacer(minLength: 0)
                }
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

    // MARK: - Closet item card

    @ViewBuilder
    private func closetItemCardView(itemID: String) -> some View {
        if let item = closetItem(for: itemID) {
            HStack(spacing: 12) {
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isUser ? Color.white.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "hanger")
                                .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                        )
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isUser ? .white : .primary)
                    Text(item.category.displayName)
                        .font(.caption)
                        .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
                    if !item.colorTags.isEmpty {
                        Text(item.colorTags.prefix(4).joined(separator: ", "))
                            .font(.caption2)
                            .foregroundStyle(isUser ? .white.opacity(0.7) : .secondary)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .background(isUser ? Color.white.opacity(0.12) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isUser ? Color.white.opacity(0.15) : Color(.separator).opacity(0.5), lineWidth: 1)
            )
        } else {
            HStack {
                Image(systemName: "hanger")
                Text("Closet item")
                    .font(.caption)
                Spacer()
            }
            .padding(10)
            .foregroundStyle(isUser ? .white.opacity(0.8) : .secondary)
            .background(isUser ? Color.white.opacity(0.12) : Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func closetItem(for itemID: String) -> ClothingItem? {
        guard let uuid = UUID(uuidString: itemID) else { return nil }
        let descriptor = FetchDescriptor<ClothingItem>(
            predicate: #Predicate { $0.id == uuid }
        )
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Map

    @ViewBuilder
    private func mapView(latitude: Double, longitude: Double, label: String) -> some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let camera = MapCameraPosition.region(
            MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
        )

        Map(position: .constant(camera)) {
            Marker(label, coordinate: coordinate)
        }
        .mapStyle(.standard)
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isUser ? Color.white.opacity(0.15) : Color(.separator).opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Action button

    @ViewBuilder
    private func actionButtonView(title: String, actionID: String) -> some View {
        Button {
            // Placeholder for action handling; the host view can observe this via a callback if needed.
        } label: {
            HStack {
                Image(systemName: actionIcon(for: actionID))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .foregroundStyle(isUser ? Theme.Colors.primary : .white)
            .background(isUser ? Color.white : Theme.Colors.primary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func actionIcon(for actionID: String) -> String {
        if actionID.contains("try-on") || actionID.contains("tryon") {
            return "camera.viewfinder"
        }
        if actionID.contains("closet") {
            return "hanger"
        }
        if actionID.contains("calendar") {
            return "calendar"
        }
        return "arrow.right.circle"
    }

    // MARK: - Paragraph

    @ViewBuilder
    private func paragraphView(content: String) -> some View {
        let textView = Text(parseInlineStyles(content))
            .font(.body)
            .foregroundStyle(isUser ? .white : .primary)

        if textSelectionEnabled {
            textView.textSelection(.enabled)
        } else {
            textView
        }
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

private struct CheckItem: Identifiable, Equatable {
    let id = UUID()
    let isChecked: Bool
    var text: String
}

private enum MarkdownBlock: Equatable {
    case heading1(String)
    case heading2(String)
    case heading3(String)
    case bulletList([String])
    case numberedList([String])
    case checklist([CheckItem])
    case codeBlock(String, String?)
    case table([String], [[String]])
    case blockquote(String)
    case divider
    case closetItemCard(String)
    case map(Double, Double, String)
    case actionButton(String, String)
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

/// True for a checklist item `- [ ]` or `- [x]`.
private func parseChecklistItem(_ line: String) -> CheckItem? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    let patterns = [
        ("- [ ] ", false),
        ("- [x] ", true),
        ("- [X] ", true),
        ("* [ ] ", false),
        ("* [x] ", true),
        ("* [X] ", true)
    ]
    for (prefix, checked) in patterns {
        if trimmed.hasPrefix(prefix) {
            return CheckItem(isChecked: checked, text: String(trimmed.dropFirst(prefix.count)))
        }
    }
    return nil
}

/// Parses a closet item card marker `[card:closet-item-uuid]`.
private func parseClosetCardMarker(_ line: String) -> String? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[card:") && trimmed.hasSuffix("]") else { return nil }
    let start = trimmed.index(trimmed.startIndex, offsetBy: 6)
    let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
    let id = String(trimmed[start..<end]).trimmingCharacters(in: .whitespaces)
    return id.isEmpty ? nil : id
}

/// Parses a map marker `[map:lat,lon|label]`.
private func parseMapMarker(_ line: String) -> (Double, Double, String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[map:") && trimmed.hasSuffix("]") else { return nil }
    let start = trimmed.index(trimmed.startIndex, offsetBy: 5)
    let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
    let content = String(trimmed[start..<end])

    let parts = content.split(separator: "|", maxSplits: 1).map(String.init)
    let coordsPart = parts.first?.trimmingCharacters(in: .whitespaces) ?? ""
    let label = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "Location"

    let coords = coordsPart.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
    guard coords.count == 2 else { return nil }
    return (coords[0], coords[1], label)
}

/// Parses an action button marker `[action:title|actionID]`.
private func parseActionButtonMarker(_ line: String) -> (String, String)? {
    let trimmed = line.trimmingCharacters(in: .whitespaces)
    guard trimmed.hasPrefix("[action:") && trimmed.hasSuffix("]") else { return nil }
    let start = trimmed.index(trimmed.startIndex, offsetBy: 8)
    let end = trimmed.index(trimmed.endIndex, offsetBy: -1)
    let content = String(trimmed[start..<end])

    let parts = content.split(separator: "|", maxSplits: 1).map(String.init)
    guard parts.count == 2 else { return nil }
    let title = parts[0].trimmingCharacters(in: .whitespaces)
    let actionID = parts[1].trimmingCharacters(in: .whitespaces)
    return title.isEmpty || actionID.isEmpty ? nil : (title, actionID)
}

private func parseMarkdown(_ text: String) -> [MarkdownBlock] {
    let lines = text.components(separatedBy: .newlines)
    var blocks: [MarkdownBlock] = []
    var currentParagraph = ""
    var currentBulletItems: [String] = []
    var currentNumberedItems: [String] = []
    var currentChecklistItems: [CheckItem] = []

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

    func flushChecklist() {
        if !currentChecklistItems.isEmpty {
            blocks.append(.checklist(currentChecklistItems))
            currentChecklistItems = []
        }
    }

    func flushAll() {
        flushParagraph()
        flushBullets()
        flushNumbered()
        flushChecklist()
    }

    var i = 0
    while i < lines.count {
        let line = lines[i]
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Rich markers (single-line blocks).
        if let cardID = parseClosetCardMarker(trimmed) {
            flushAll()
            blocks.append(.closetItemCard(cardID))
            i += 1
            continue
        }

        if let (lat, lon, label) = parseMapMarker(trimmed) {
            flushAll()
            blocks.append(.map(lat, lon, label))
            i += 1
            continue
        }

        if let (title, actionID) = parseActionButtonMarker(trimmed) {
            flushAll()
            blocks.append(.actionButton(title, actionID))
            i += 1
            continue
        }

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

        // Checklist item.
        if let checkItem = parseChecklistItem(trimmed) {
            flushParagraph()
            flushBullets()
            flushNumbered()
            currentChecklistItems.append(checkItem)
            i += 1
            continue
        }

        // Bullet list.
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
            flushParagraph()
            flushNumbered()
            flushChecklist()
            currentBulletItems.append(String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces))
            i += 1
            continue
        }

        // Numbered list.
        if let match = trimmed.firstMatch(of: /^\d+\.\s+(.+)$/) {
            flushParagraph()
            flushBullets()
            flushChecklist()
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
        if !currentChecklistItems.isEmpty && line.hasPrefix("  ") {
            currentChecklistItems[currentChecklistItems.count - 1].text += " " + trimmed
            i += 1
            continue
        }

        // Regular paragraph text.
        flushBullets()
        flushNumbered()
        flushChecklist()
        currentParagraph += currentParagraph.isEmpty ? trimmed : " " + trimmed
        i += 1
    }

    flushAll()
    return blocks
}
