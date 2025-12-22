import SwiftUI

struct RootView: View {
    @State private var menuID: Int = 0

    var body: some View {
        ZStack {
            contentFor(menuID)
                .ignoresSafeArea()

            VStack {
                Spacer()
                BottomBar(menuID: $menuID)
                    .ignoresSafeArea(edges: .bottom)
            }
        }
    }

    @ViewBuilder
    private func contentFor(_ id: Int) -> some View {
        switch id {
        case 0:
            HomeView()
        case 1:
            CustomerView()
        default:
            HomeView()
        }
    }
}

#Preview {
    RootView()
}
