import SwiftUI

struct DiscoverView: View {
  var body: some View {
    NavigationView {
      Text("DiscoverView!")
        .navigationTitle(Strings.tabbar_discover())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackgroundLightGray()
    }
    .navigationViewStyle(StackNavigationViewStyle())
  }
}

struct DiscoverView_Previews: PreviewProvider {
  static var previews: some View {
    DiscoverView()
  }
}
