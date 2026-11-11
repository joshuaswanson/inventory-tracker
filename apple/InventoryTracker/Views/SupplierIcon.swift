import SwiftUI

struct SupplierIcon: View {
    let supplier: Supplier
    var size: CGFloat = 44

    private var assetName: String { "Supplier-\(supplier.id)" }

    private var hasLogo: Bool {
        #if os(macOS)
        NSImage(named: assetName) != nil
        #else
        UIImage(named: assetName) != nil
        #endif
    }

    var body: some View {
        Group {
            if hasLogo {
                Image(assetName)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .background(Color.white)
            } else {
                Text(supplier.name.prefix(1).uppercased())
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.primaryDark)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.primaryBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size * 0.23, style: .continuous).stroke(Theme.border, lineWidth: 1))
        .accessibilityHidden(true)
    }
}
