import SwiftUI

struct RootView: View {
    @State private var menuID: Int = 0

    var body: some View {
        ZStack {
            contentFor(menuID)

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
            CustomerView()
        case 1:
            TicketView()
        default:
            TicketView()
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Customer.self, inMemory: true)
}
