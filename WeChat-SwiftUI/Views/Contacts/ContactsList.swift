import SwiftUI
import SwiftUIRedux

struct ContactsList: ConnectedView {
  struct Props {
    let contacts: Loadable<[User]>
    let loadContacts: () -> Void
  }

  func map(state: AppState, dispatch: @escaping (Action) -> Void) -> Props {
    Props(
      contacts: state.contactsState.contacts,
      loadContacts: { dispatch(ContactsActions.LoadContacts()) }
    )
  }

  func body(props: Props) -> some View {
    switch props.contacts {
    case .notRequested:
      return AnyView(Text("").onAppear(perform: props.loadContacts))

    case let .isLoading(last, _):
      return AnyView(loadingView(last))

    case let .loaded(users):
      return AnyView(loadedView(users, showLoading: false))

    case let .failed(error):
      return AnyView(ErrorView(error: error, retryAction: props.loadContacts))
    }
  }
}

// MARK: - Display Content
private extension ContactsList {

  func loadingView(_ previouslyLoaded: [User]?) -> some View {
    if let result = previouslyLoaded {
      return AnyView(loadedView(result, showLoading: true))
    } else {
      return AnyView(ActivityIndicatorView().padding())
    }
  }

  func loadedView(_ contacts: [User], showLoading: Bool) -> some View {

    let contactGroups = contacts
      .groupedBy { String($0.name.first ?? Character("")) }
      .sorted(by: { $0.key < $1.key })

    return ScrollViewReader { proxy in
      ZStack {
        groupedContactsList(contactGroups)
        if showLoading {
          ActivityIndicatorView(color: .gray)
            .padding()
        }
      }
      .overlay(
        SectionIndexTitles(proxy: proxy, titles: contactGroups.map { $0.key })
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.trailing, 2)
      )
    }
  }

  func groupedContactsList(_ group: [(key: String, value: [User])]) -> some View {
    List {
      ForEach(group, id: \.key) { category, contacts in
        Section(header: SectionHeader(title: category)) {
          ForEach(contacts) { contact in
            ZStack(alignment: .leading) {
              NavigationLink(destination: ContactDetail(contact: contact)) {
                EmptyView()
              }
              .opacity(0.0) // 为了隐藏 NavigationLink 右边的箭头
              .buttonStyle(PlainButtonStyle())
              ContactRow(contact: contact)
            }
          }
        }
      }
    }
    .listStyle(PlainListStyle())
  }
}

// MARK: - Helper Types
private extension ContactsList {

  // MARK: - SectionHeader

  struct SectionHeader: View {
    let title: String

    var body: some View {
      Text(title)
        .foregroundColor(.text_info_200)
        .font(.system(size: 14, weight: .medium))
        .padding(EdgeInsets(top: 5, leading: 20, bottom: 5, trailing: 0))
        .frame(width: UIScreen.main.bounds.width, alignment: .leading)
        .background(Color.bg_info_200)
    }
  }

  // MARK: - SectionIndexTitles

  struct SectionIndexTitles: View {

    let proxy: ScrollViewProxy
    let titles: [String]

    @GestureState
    private var dragLocation: CGPoint = .zero

    @State
    private var selectedTitle: String?

    @State
    private var showSelectionBubble = false

    var body: some View {
      VStack {
        ForEach(titles, id: \.self) { title in
          let isSelected = isSelectedIndex(withTitle: title)
          HStack {
            Spacer()

            SectionIndexSelectionBubble {
              Text(title)
                .foregroundColor(.white)
                .font(.system(size: 25, weight: .bold))
            }
            .frame(width: 70, height: 50)
            .opacity(selectionBubbleOpacityForIndex(withTitle: title))
            .animation(showSelectionBubble ? .none : .easeOut)

            SectionIndexTitle(
              title: title,
              isSelected: isSelected,
              onTap: {
                scrollToTitle(title)

                showSelectionBubble = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                  showSelectionBubble = false
                }
              }
            )
            .background(dragObserver(title: title))
          }
          .frame(height: 16)
        }
      }
      .gesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
          .updating($dragLocation) { value, state, _ in
            state = value.location
          }
          .onEnded({ _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
              showSelectionBubble = false
            }
          })
      )
    }

    private func isSelectedIndex(withTitle title: String) -> Bool? {
      selectedTitle == nil ? nil : selectedTitle! == title
    }

    private func selectionBubbleOpacityForIndex(withTitle title: String) -> Double {
      let isSelected = isSelectedIndex(withTitle: title)
      return isSelected == nil ? 0 : (isSelected! && showSelectionBubble) ? 1 : 0
    }

    private func dragObserver(title: String) -> some View {
      GeometryReader { geometry in
        dragObserver(geometry: geometry, title: title)
      }
    }

    private func dragObserver(geometry: GeometryProxy, title: String) -> some View {
      if geometry.frame(in: .global).contains(dragLocation) {
        DispatchQueue.main.async {
          scrollToTitle(title)
          showSelectionBubble = true
        }
      }
      return Rectangle().fill(Color.clear)
    }

    private func scrollToTitle(_ title: String) {
      guard selectedTitle != title else {
        return
      }
      proxy.scrollTo(title, anchor: .top)
      selectedTitle = title
      Haptics.impact(.light)
    }
  }

  // MARK: - SectionIndexTitle

  struct SectionIndexTitle: View {

    let title: String
    let isSelected: Bool?
    let onTap: () -> Void

    var body: some View {
      Text(title)
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(foregroundColor)
        .frame(width: 16, height: 16)
        .background(background)
        .cornerRadius(cornerRadius)
        .contentShape(Rectangle()) // 解决问题：背景色为透明时，手势无效
        .onTapGesture(perform: onTap)
    }

    private var foregroundColor: Color {
      isSelected == nil ?
        .text_info_500 :
        isSelected! ? .white : .text_info_500
    }

    private var background: Color {
      isSelected == nil ?
        .clear :
        isSelected! ? .highlighted : .clear
    }

    private var cornerRadius: CGFloat {
      isSelected == nil ?
        0 :
        isSelected! ? 8 : 0
    }
  }

  // MARK: - SectionIndexSelectionBubble

  struct SectionIndexSelectionBubble<Title: View>: View {
    let title: () -> Title

    var body: some View {
      GeometryReader { geo in

        let startDegree: CGFloat = 45
        let startRadius: CGFloat = startDegree * .pi / 180
        let height = geo.size.height
        let radius = height * 0.5

        let deltaX = cos(startRadius) * radius
        let deltaY = sin(startRadius) * radius

        HStack(spacing: -(radius - deltaX)) {
          ZStack {
            Path { path in
              path.addArc(
                center: .init(x: radius, y: radius),
                radius: radius,
                startAngle: Angle(degrees: 360 - Double(startDegree)),
                endAngle: Angle(degrees: Double(startDegree)),
                clockwise: true
              )
            }

            title()
          }
          .frame(width: geo.size.height, height: geo.size.height)

          Path { path in
            let topPoint = CGPoint(x: 0, y: radius - deltaY)
            let bottomPoint = CGPoint(x: 0, y: radius + deltaY)

            let deltaX2 = tan(startRadius) * deltaY
            let leftPoint = CGPoint(x: deltaX2, y: radius)

            path.move(to: topPoint)
            path.addLine(to: leftPoint)
            path.addLine(to: bottomPoint)
          }
          .frame(height: geo.size.height)

          Spacer()
        }
        .foregroundColor(.hex("#C9C9C9"))
      }
    }
  }
}

struct ContactsList_Previews: PreviewProvider {
  static var previews: some View {
    ContactsList()
  }
}
