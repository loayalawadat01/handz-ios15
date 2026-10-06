//
//  ReceiptPaper.swift
//  Handz
//
//  The receipt itself: a paper card with a torn bottom edge, a checkmark that
//  draws itself, a stamp, dotted lines and the price lines. It draws whatever
//  `reveal` says is showing, so the receipt screen can bring the parts in one
//  after another, and the PDF can draw everything at once.
//

import SwiftUI
import UniformTypeIdentifiers

/// Which parts of the receipt are showing.
struct ReceiptReveal: Equatable {
    var check = false        // checkmark drawn in its circle
    var stamp = false        // the "PAID" stamp
    var amount = 0.0         // the big number (it counts up to this)
    var divider = false      // dotted lines drawn left to right
    var rows = 0             // how many sections and price lines are showing
    var strike = false       // a line through the old total (refunds)
    var refund = false       // the red refund line

    static func all(_ receipt: Receipt) -> ReceiptReveal {
        ReceiptReveal(check: true, stamp: true, amount: receipt.final.amount, divider: true,
                      rows: ReceiptPaper.rowCount(receipt), strike: true, refund: true)
    }
}

struct ReceiptPaper: View {
    let receipt: Receipt
    let reveal: ReceiptReveal

    /// Sections that come in one by one: the job, each price line, the total, the details.
    static func rowCount(_ receipt: Receipt) -> Int {
        receipt.lines.count + 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar
            amountBlock
            ReceiptDottedLine(drawn: reveal.divider)
            row(0) { jobBlock }
            ReceiptDottedLine(drawn: reveal.divider)
            priceBlock
            ReceiptDottedLine(drawn: reveal.divider)
            row(Self.rowCount(receipt) - 1) { detailsBlock }
        }
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 34)   // room for the torn edge
        .background(
            ReceiptPaperShape()
                .fill(HandzColor.surface)
                .shadow(color: HandzColor.shadow.opacity(0.12), radius: 12, x: 0, y: 6)
        )
    }

    // MARK: - Top: Handz, what this is, receipt number

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Handz")
                    .font(HandzTypography.title)
                    .foregroundColor(HandzColor.primary)
                Text(receipt.title)
                    .font(HandzTypography.captionBold)
                    .foregroundColor(HandzColor.textSecondary)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(receipt.receiptNumber ?? (receipt.status == .canceled ? "Not charged" : "Not charged yet"))
                    .font(.system(.footnote, design: .monospaced).weight(.semibold))
                    .foregroundColor(HandzColor.textPrimary)
                Text(receipt.issuedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(HandzTypography.caption)
                    .foregroundColor(HandzColor.textSecondary)
            }
        }
    }

    // MARK: - Checkmark, big number, stamp

    private var amountBlock: some View {
        VStack(spacing: 10) {
            ReceiptCheckmark(drawn: reveal.check, color: statusColor, icon: statusIcon)
            Text("")
                .modifier(CountingAmount(amount: reveal.amount, size: 44,
                                         color: receipt.isWorker ? HandzColor.accentInk : HandzColor.textPrimary))
            Text(amountLabel)
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            ReceiptStamp(text: receipt.statusLabel, color: statusColor, shown: reveal.stamp)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(receipt.statusLabel). \(receipt.final.label) \(HandzMoney.text(receipt.final.amount))")
    }

    private var amountLabel: String {
        if receipt.wasRefunded && !reveal.refund { return receipt.total.label }
        return receipt.final.label
    }

    // MARK: - The job and the other person

    private var jobBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(receipt.job.title)
                .font(HandzTypography.headline)
                .foregroundColor(HandzColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                initials(receipt.otherPerson.name)
                VStack(alignment: .leading, spacing: 1) {
                    Text(receipt.otherPerson.name)
                        .font(HandzTypography.callout.weight(.semibold))
                        .foregroundColor(HandzColor.textPrimary)
                    Text(receipt.otherPerson.role == "worker" ? "Your worker" : "Customer")
                        .font(HandzTypography.caption)
                        .foregroundColor(HandzColor.textSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                if let when = receipt.job.completedAt ?? receipt.job.scheduledAt {
                    detailLabel(when.formatted(date: .abbreviated, time: .shortened), icon: "calendar")
                }
                detailLabel(hoursText, icon: "clock")
                if !receipt.job.place.isEmpty {
                    detailLabel(receipt.job.place, icon: "mappin.and.ellipse")
                }
            }
        }
    }

    private var hoursText: String {
        if let actual = receipt.job.actualHours {
            return "Worked \(hours(actual))"
        }
        return "Booked for \(hours(receipt.job.durationHours))"
    }

    private func hours(_ value: Double) -> String {
        let text = String(format: "%g", (value * 10).rounded() / 10)
        return value == 1 ? "1 hour" : "\(text) hours"
    }

    // MARK: - Price lines, total, refund, what was paid in the end

    private var priceBlock: some View {
        VStack(spacing: 10) {
            ForEach(Array(receipt.lines.enumerated()), id: \.offset) { index, line in
                row(index + 1) { priceRow(line.label, line.amount) }
            }
            row(receipt.lines.count + 1) { totalRow }
            if receipt.wasRefunded {
                refundRows
            }
        }
    }

    private var totalRow: some View {
        HStack {
            Text(receipt.total.label)
                .font(HandzTypography.headline)
            Spacer()
            Text(HandzMoney.text(receipt.total.amount))
                .font(HandzTypography.headline.monospacedDigit())
                .overlay(alignment: .leading) {
                    if receipt.wasRefunded {
                        Rectangle()
                            .fill(HandzColor.danger)
                            .frame(height: 2)
                            .scaleEffect(x: reveal.strike ? 1 : 0.001, y: 1, anchor: .leading)
                    }
                }
        }
        .foregroundColor(HandzColor.textPrimary)
        .padding(.top, 4)
    }

    private var refundRows: some View {
        VStack(spacing: 10) {
            HStack {
                Label("Refunded", systemImage: "arrow.uturn.backward")
                    .font(HandzTypography.callout.weight(.semibold))
                Spacer()
                Text("-" + HandzMoney.text(receipt.refunded))
                    .font(HandzTypography.callout.weight(.semibold).monospacedDigit())
            }
            .foregroundColor(HandzColor.danger)

            HStack {
                Text(receipt.final.label)
                    .font(HandzTypography.headline)
                Spacer()
                Text(HandzMoney.text(receipt.final.amount))
                    .font(HandzTypography.headline.monospacedDigit())
            }
            .foregroundColor(HandzColor.textPrimary)
        }
        .opacity(reveal.refund ? 1 : 0)
        .offset(x: reveal.refund ? 0 : 24)
    }

    private func priceRow(_ label: String, _ amount: Double) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
            Text(HandzMoney.text(amount))
                .monospacedDigit()
        }
        .font(HandzTypography.callout)
        .foregroundColor(HandzColor.textSecondary)
    }

    // MARK: - Dates, card, number, note

    private var detailsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if receipt.status == .succeeded {
                detailRow(receipt.isWorker ? "Paid to you" : "Charged", receipt.issuedAt.formatted(date: .abbreviated, time: .shortened))
            }
            if let card = receipt.card {
                detailRow("Card", "\((card.brand ?? "Card").capitalized) ending \(card.last4)")
            }
            ForEach(Array(receipt.refunds.enumerated()), id: \.offset) { _, refund in
                detailRow("Refund", "\(HandzMoney.text(refund.amount)) on \(refund.createdAt.formatted(date: .abbreviated, time: .omitted))")
            }
            if let number = receipt.receiptNumber {
                detailRow("Receipt", number)
            }

            Text(receipt.note)
                .font(HandzTypography.caption)
                .foregroundColor(HandzColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            Text("Thank you for using Handz.")
                .font(HandzTypography.captionBold)
                .foregroundColor(HandzColor.primary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
        }
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundColor(HandzColor.textSecondary)
            Spacer(minLength: 12)
            Text(value)
                .foregroundColor(HandzColor.textPrimary)
                .multilineTextAlignment(.trailing)
        }
        .font(HandzTypography.caption)
    }

    private func detailLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(HandzTypography.caption.weight(.semibold))
            .foregroundColor(HandzColor.textSecondary)
    }

    private func initials(_ name: String) -> some View {
        let letters = name.split(separator: " ").prefix(2).compactMap { $0.first }.map { String($0) }.joined()
        return Text(letters.uppercased())
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .foregroundColor(HandzColor.primaryInk)
            .frame(width: 40, height: 40)
            .background(Circle().fill(HandzColor.primaryTint))
            .accessibilityHidden(true)
    }

    /// Sections fade and rise in one after another.
    private func row<Content: View>(_ index: Int, @ViewBuilder _ content: () -> Content) -> some View {
        let shown = reveal.rows > index
        return content()
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 10)
    }

    // MARK: - Status look

    private var statusColor: Color {
        switch receipt.status {
        case .succeeded: return receipt.wasRefunded ? HandzColor.warning : HandzColor.accent
        case .authorized, .pending, .simulated: return HandzColor.primary
        case .canceled: return HandzColor.textSecondary
        case .failed: return HandzColor.danger
        }
    }

    /// nil means "draw the checkmark".
    private var statusIcon: String? {
        switch receipt.status {
        case .succeeded: return nil
        case .authorized: return "lock.fill"
        case .pending, .simulated: return "clock.fill"
        case .canceled: return "arrow.uturn.backward"
        case .failed: return "xmark"
        }
    }
}

// MARK: - Pieces

/// A circle that draws itself, with a checkmark (or an icon) inside.
struct ReceiptCheckmark: View {
    let drawn: Bool
    let color: Color
    let icon: String?

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.12))
            Circle()
                .trim(from: 0, to: drawn ? 1 : 0)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(color)
                    .scaleEffect(drawn ? 1 : 0.4)
                    .opacity(drawn ? 1 : 0)
            } else {
                ReceiptCheckShape()
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    .frame(width: 26, height: 19)
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityHidden(true)
    }
}

struct ReceiptCheckShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// The tilted stamp ("PAID") that pops onto the receipt.
struct ReceiptStamp: View {
    let text: String
    let color: Color
    let shown: Bool

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .heavy, design: .rounded))
            .tracking(1.4)
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(color, lineWidth: 2)
            )
            .rotationEffect(.degrees(-12))
            .scaleEffect(shown ? 1 : 1.9)
            .opacity(shown ? 0.92 : 0)
            .accessibilityHidden(true)
    }
}

/// A dotted line that draws from left to right.
struct ReceiptDottedLine: View {
    let drawn: Bool

    var body: some View {
        ReceiptLineShape()
            .trim(from: 0, to: drawn ? 1 : 0)
            .stroke(HandzColor.textFaint.opacity(0.7),
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round, dash: [1, 6]))
            .frame(height: 2)
            .accessibilityHidden(true)
    }
}

struct ReceiptLineShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Paper with rounded top corners and a torn (zig-zag) bottom edge.
struct ReceiptPaperShape: Shape {
    var cornerRadius: CGFloat = 22
    var toothWidth: CGFloat = 14
    var toothHeight: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bottom = rect.maxY - toothHeight
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: bottom))

        let count = max(1, Int((rect.width / toothWidth).rounded()))
        let step = rect.width / CGFloat(count)
        var x = rect.maxX
        for _ in 0..<count {
            path.addLine(to: CGPoint(x: x - step / 2, y: rect.maxY))
            x -= step
            path.addLine(to: CGPoint(x: x, y: bottom))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - PDF

enum ReceiptPDF {
    static func fileName(_ receipt: Receipt) -> String {
        "Handz receipt \(receipt.receiptNumber ?? String(receipt.id.prefix(8)))"
    }

    /// Draws the whole receipt (light colors) into a PDF file and returns where it is.
    @MainActor
    static func make(_ receipt: Receipt) -> URL? {
        let content = ReceiptPaper(receipt: receipt, reveal: .all(receipt))
            .frame(width: 380)
            .padding(24)
            .background(Color.white)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: content)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName(receipt)).pdf")
        var made = false
        renderer.render { size, draw in
            var box = CGRect(origin: .zero, size: size)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            draw(pdf)
            pdf.endPDFPage()
            pdf.closePDF()
            made = true
        }
        return made ? url : nil
    }
}

/// Lets "Save PDF" put the receipt in the Files app.
struct ReceiptPDFDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.pdf] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
