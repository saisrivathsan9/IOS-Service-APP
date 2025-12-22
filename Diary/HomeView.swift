import SwiftUI

struct HomeView: View {
    @State private var menuID: Int = 0
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Text("Welcome")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.leading)
                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(Color.accentColor))
                    }
                    .padding(.trailing)
                }
                .padding(.vertical, 20)
                .background(Color.white)

                Spacer()

                // Main content placeholder
                Text("Home Content")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

        
            }
        }
    }
}

#Preview {
    HomeView()
}
