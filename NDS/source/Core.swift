//---------------------------------------------------------------------------------
//
//  Core.swift -- embedded mini-core of the Fueling DS UI.
//
//  Copied from ClassicUI's ports/NDS ClassicCore.swift (branch feature/nds):
//  Embedded Swift has no Mirror, no untyped existentials, no Foundation and
//  no Observation, so neither the desktop SwiftUI-subset resolver nor
//  FuelingModel's Store/view models can compile for this target. The port
//  carries its own small screen model that reproduces the same semantics --
//  menu rows with right-aligned values, and stack navigation with per-screen
//  selection restore and scroll windowing.
//
//  Differences from the ClassicUI original: `Screen` gains `showsSearch`
//  (the locations list draws the search field fed by the bottom-screen
//  keyboard, and lays rows out below it), and titles/details are runtime
//  byte arrays rather than StaticString -- location names and fuel prices
//  arrive over wifi at runtime, not at compile time.
//
//---------------------------------------------------------------------------------

/// One selectable menu row.
struct MenuItem {

  enum Action {
    /// Non-interactive row.
    case none
    /// Pushes a screen built on demand.
    case push(() -> Screen)
    /// Runs an action on select.
    case run(() -> Void)
  }

  var title: [UInt8]
  var action: Action
  /// Right-aligned value bytes, recomputed on every redraw.
  var detail: (() -> [UInt8])?

  var isNavigation: Bool {
    if case .push = action { return true }
    return false
  }

  init(
    _ title: [UInt8], action: Action = .none,
    detail: (() -> [UInt8])? = nil
  ) {
    self.title = title
    self.action = action
    self.detail = detail
  }

  init(
    _ title: StaticString, action: Action = .none,
    detail: (() -> [UInt8])? = nil
  ) {
    self.init(staticBytes(title), action: action, detail: detail)
  }
}

/// A full screen: a menu of rows, optionally headed by the search field.
final class Screen {

  enum Content {
    case menu([MenuItem])
  }

  var title: [UInt8]
  var content: Content
  var showsSearch: Bool
  var selection: Int32 = 0
  var scrollOffset: Int32 = 0

  init(title: [UInt8], content: Content, showsSearch: Bool = false) {
    self.title = title
    self.content = content
    self.showsSearch = showsSearch
  }

  convenience init(title: StaticString, content: Content, showsSearch: Bool = false) {
    self.init(title: staticBytes(title), content: content, showsSearch: showsSearch)
  }

  var visibleRowCount: Int32 {
    showsSearch ? visibleRowsWithSearch : visibleRows
  }
}

/// The navigation stack: select pushes, B pops, and each screen's
/// selection and scroll position are restored when navigating back.
final class Navigator {

  private(set) var stack: [Screen]

  init(root: Screen) {
    stack = [root]
  }

  var top: Screen { stack[stack.count - 1] }

  /// Scroll window so the selection is always visible and the offset never
  /// leaves blank space at the bottom (ClassicUI's NavigationModel).
  static func scrollOffset(selection: Int32, current: Int32, rowCount: Int32, visibleRows: Int32)
    -> Int32
  {
    var offset = current
    if selection < offset {
      offset = selection
    }
    if selection >= offset + visibleRows {
      offset = selection - visibleRows + 1
    }
    let maxOffset = rowCount > visibleRows ? rowCount - visibleRows : 0
    return min(max(offset, 0), maxOffset)
  }

  /// Moves the selection by `delta` rows (positive = down).
  func moveSelection(by delta: Int32, rowCount: Int32, visibleRows: Int32) {
    guard rowCount > 0 else { return }
    let screen = top
    screen.selection = min(max(screen.selection + delta, 0), rowCount - 1)
    screen.scrollOffset = Self.scrollOffset(
      selection: screen.selection,
      current: screen.scrollOffset,
      rowCount: rowCount,
      visibleRows: visibleRows)
  }

  func push(_ screen: Screen) {
    stack.append(screen)
  }

  /// Pops the top screen. Returns `false` when already at the root.
  func pop() -> Bool {
    guard stack.count > 1 else { return false }
    stack.removeLast()
    return true
  }
}
