import SwiftUI

struct SectionHeaderTitle: View {
  let title: String

  var body: some View {
    Text(title)
      .foregroundColor(.text_info_200)
      .font(.system(size: 14, weight: .medium))
      .padding(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 0))
      .frame(width: UIScreen.main.bounds.width, alignment: .leading)
      .background(Color.app_bg)
  }
}

struct SectionHeaderTitle_Previews: PreviewProvider {
    static var previews: some View {
        SectionHeaderTitle(title: "Hello")
    }
}
