//
//  GlacierSection.swift
//  Glacier
//

import SwiftUI

struct GlacierSectionOptions: OptionSet {
    let rawValue: Int

    static let isBordered = GlacierSectionOptions(rawValue: 1 << 0)
    static let hasDividers = GlacierSectionOptions(rawValue: 1 << 1)

    static let plain: GlacierSectionOptions = []
    static let `default`: GlacierSectionOptions = [.isBordered, .hasDividers]
}

struct GlacierSection<Header: View, Content: View, Footer: View>: View {
    private let header: Header
    private let content: Content
    private let footer: Footer
    private let spacing: CGFloat
    private let options: GlacierSectionOptions

    private var isBordered: Bool { options.contains(.isBordered) }
    private var hasDividers: Bool { options.contains(.hasDividers) }

    init(
        spacing: CGFloat = .glacierSectionDefaultSpacing,
        options: GlacierSectionOptions = .default,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.spacing = spacing
        self.options = options
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    init(
        spacing: CGFloat = .glacierSectionDefaultSpacing,
        options: GlacierSectionOptions = .default,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) where Header == EmptyView {
        self.init(spacing: spacing, options: options) {
            EmptyView()
        } content: {
            content()
        } footer: {
            footer()
        }
    }

    init(
        spacing: CGFloat = .glacierSectionDefaultSpacing,
        options: GlacierSectionOptions = .default,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) where Footer == EmptyView {
        self.init(spacing: spacing, options: options) {
            header()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    init(
        spacing: CGFloat = .glacierSectionDefaultSpacing,
        options: GlacierSectionOptions = .default,
        @ViewBuilder content: () -> Content
    ) where Header == EmptyView, Footer == EmptyView {
        self.init(spacing: spacing, options: options) {
            EmptyView()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    init(
        _ title: LocalizedStringKey,
        spacing: CGFloat = .glacierSectionDefaultSpacing,
        options: GlacierSectionOptions = .default,
        @ViewBuilder content: () -> Content
    ) where Header == Text, Footer == EmptyView {
        self.init(spacing: spacing, options: options) {
            Text(title).font(.headline)
        } content: {
            content()
        }
    }

    var body: some View {
        Section {
            if isBordered {
                GlacierGroupBox {
                    header
                } content: {
                    contentLayout
                } footer: {
                    footer
                }
            } else {
                VStack(alignment: .leading) {
                    header
                        .accessibilityAddTraits(.isHeader)
                        .padding([.top, .leading], 8)
                        .padding(.bottom, 2)

                    contentLayout

                    footer
                        .padding([.bottom, .leading], 8)
                        .padding(.top, 2)
                }
                .focusSection()
                .accessibilityElement(children: .contain)
            }
        }
        .focusSection()
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var contentLayout: some View {
        if hasDividers {
            _VariadicView.Tree(GlacierSectionLayout(spacing: spacing)) {
                content.frame(maxWidth: .infinity)
            }
        } else {
            content.frame(maxWidth: .infinity)
        }
    }
}

// MARK: - GlacierSectionLayout

private struct GlacierSectionLayout: _VariadicView_UnaryViewRoot {
    let spacing: CGFloat

    @ViewBuilder
    func body(children: _VariadicView.Children) -> some View {
        let last = children.last?.id
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(children) { child in
                child
                if child.id != last {
                    GlacierSectionDivider()
                }
            }
        }
    }
}

// MARK: - GlacierSectionDivider

private struct GlacierSectionDivider: View {
    var body: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.separator.quinary)
                .frame(height: 1)
        } else {
            Divider()
        }
    }
}

extension CGFloat {
    /// The default spacing for an ``GlacierSection``.
    static let glacierSectionDefaultSpacing: CGFloat = if #available(macOS 26.0, *) { 11 } else { 10 }
}
