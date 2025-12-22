import SwiftUI

struct BottomBar: View {
    @Namespace private var highlightNamespace
    @Binding var menuID: Int

    // Only two icons now
    private let icons = ["person.fill", "clipboard.fill"]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(icons.indices, id: \.self) { idx in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        menuID = idx
                    }
                } label: {
                    ZStack {
                        if menuID == idx {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.white.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(.white.opacity(0.35), lineWidth: 1)
                                )
                                .matchedGeometryEffect(
                                    id: "activeHighlight",
                                    in: highlightNamespace
                                )
                                .padding(.horizontal, 8)
                                .frame(height: 44)
                        }

                        Image(systemName: icons[idx])
                            .font(.system(size: 20, weight: .semibold))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .foregroundStyle(
                                idx == menuID ? Color.primary : Color.secondary
                            )
                            .contentShape(Rectangle())
                    }
                    .frame(height: 56)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(labelForIndex(idx))
            }
        }
        .frame(height: 64)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    private func labelForIndex(_ idx: Int) -> Text {
        switch idx {
        case 0: return Text("Profile")
        case 1: return Text("Clipboard")
        default: return Text("Tab")
        }
    }
}

#Preview {
    VStack {
        Spacer()
        BottomBar(menuID: .constant(0))
    }
}


#Preview {
    VStack {
        Spacer()
        BottomBar(menuID: .constant(0))
    }
}
