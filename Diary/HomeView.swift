import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Text("Welcome User")
                    .font(.headline)
                    .padding(.leading)
                Spacer()
                Button(action: {}) {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .bold))
                }
                .padding(.trailing)
            }
            .padding(.vertical, 12)
            .background(.thinMaterial)

            Spacer()

            // Main content placeholder
            Text("Home Content")
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom Bar (Menu Bar)
            HStack {
                Spacer()
                Button(action: {}) {
                    VStack {
                        Image(systemName: "house")
                        Text("Home")
                            .font(.caption2)
                    }
                }
                Spacer()
                Button(action: {}) {
                    VStack {
                        Image(systemName: "person.3")
                        Text("Customers")
                            .font(.caption2)
                    }
                }
                Spacer()
                Button(action: {}) {
                    VStack {
                        Image(systemName: "ticket")
                        Text("Tickets")
                            .font(.caption2)
                    }
                }
                Spacer()
                Button(action: {}) {
                    VStack {
                        Image(systemName: "gearshape")
                        Text("Settings")
                            .font(.caption2)
                    }
                }
                Spacer()
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.thinMaterial)
        }
    }
}

#Preview {
    HomeView()
}
