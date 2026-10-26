import SwiftUI

/// A full screen laid out as two pages either side of the fold (Flocks, Birds, Settings): a back button and the title on
/// the left page, each page scrolling on its own, nothing on the fold band. The attract flight shows faintly behind.
struct SwoopPages<Left: View, Right: View>: View {
    let info: AppCanvas
    let title: String
    let onBack: () -> Void
    /// Scroll the right page to this child id on open (Flocks: the current rank, REVIEW-1 P1-12).
    var scrollRightTo: Int? = nil
    @ViewBuilder let left: () -> Left
    @ViewBuilder let right: () -> Right

    var body: some View {
        let lp = info.leftPage
        let rp = info.rightPage
        let top = info.top
        let bottomPad = max(info.size.height - info.bottom, 12)
        ZStack(alignment: .topLeading) {
            SwoopTheme.backdrop
                .frame(width: info.size.width, height: info.size.height)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    SwoopIconButton(systemName: "chevron.left", label: "Back", action: onBack)
                    Text(title)
                        .font(SwoopTheme.display(info.isCompact ? 28 : 34))
                        .foregroundStyle(SwoopTheme.foam)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                }
                ScrollView(showsIndicators: false) {
                    left()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, bottomPad)
                }
            }
            .padding(.top, top)
            .frame(width: lp.width, height: info.size.height, alignment: .topLeading)
            .position(x: lp.midX, y: info.size.height / 2)
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    right()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, top + 4)
                        .padding(.bottom, bottomPad)
                }
                .onAppear {
                    if let target = scrollRightTo { proxy.scrollTo(target, anchor: .center) }
                }
            }
            .frame(width: rp.width, height: info.size.height)
            .position(x: rp.midX, y: info.size.height / 2)
            if info.hasFold {
                // The crease as a faint glint, so the two pages read as one spread.
                LinearGradient(colors: [SwoopTheme.gold.opacity(0), SwoopTheme.gold.opacity(0.10),
                                        SwoopTheme.gold.opacity(0)],
                               startPoint: .leading, endPoint: .trailing)
                    .frame(width: max(info.foldMaxX - info.foldMinX, 1), height: info.size.height)
                    .position(x: (info.foldMinX + info.foldMaxX) / 2, y: info.size.height / 2)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: info.size.width, height: info.size.height, alignment: .topLeading)
    }
}

/// A section heading on a page.
struct PageHeading: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(SwoopTheme.text(12, .heavy))
            .kerning(1)
            .foregroundStyle(SwoopTheme.mist)
            .padding(.leading, 4)
            .padding(.top, 6)
    }
}
