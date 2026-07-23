//---------------------------------------------------------------------------------
//
//  Fueling for Nintendo DS -- Embedded Swift ARM9 binary.
//
//  Bootstrap copied from ClassicUI's ports/NDS main.swift (branch
//  feature/nds), with the screens swapped: the *top* screen hosts the
//  Fueling UI through the software rasterizer in Renderer.swift, drawn into
//  a double-buffered 16bpp bitmap background on the main engine
//  (map-base flip); the *bottom* (touch) screen hosts libnds' on-screen
//  keyboard on the sub engine, which types into the locations search field.
//
//  On boot the app associates with the configured access point over dswifi
//  (melonDS: the emulated "melonAP") and downloads the locations and fuel
//  prices from the test server -- see Network.swift. Nothing is hardcoded;
//  a failure shows an error screen with a Retry row.
//
//    Touch keyboard   type to filter the locations list
//    D-pad up/down    move the selection
//    A                open the selected location / retry
//    B                back, with the slide animation
//    START            exit
//
//---------------------------------------------------------------------------------

import NDS
import CoreModel
import CoreFueling

// MARK: - Video setup

// Main engine: 16bpp bitmap UI on the TOP screen.
// Sub engine: tiled background for the keyboard on the bottom (touch) screen.
videoSetMode(MODE_5_2D.rawValue)
videoSetModeSub(MODE_0_2D.rawValue)
lcdMainOnTop()
vramSetPrimaryBanks(
  VRAM_A_MAIN_BG_0x06000000, VRAM_B_MAIN_BG_0x06020000,
  VRAM_C_SUB_BG, VRAM_D_LCD)

let bg = bgInit(3, BgType_Bmp16, BgSize_B16_256x256, 0, 0)
/// The buffer currently being drawn into (the one NOT displayed).
var backBuffer = bgGetGfxPtr(bg)! + 256 * 256

func flipBuffers() {
  backBuffer = bgGetGfxPtr(bg)!
  // Each map base is 16KB; a 256x256x16bpp screen is 128KB = 8 bases.
  bgSetMapBase(bg, bgGetMapBase(bg) == 8 ? 0 : 8)
}

let canvasPixels = Int(screenWidth * screenHeight)
let renderCanvas = Canvas(
  pixels: UnsafeMutablePointer<UInt16>.allocate(capacity: canvasPixels),
  width: screenWidth, height: screenHeight)
let outgoingBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: canvasPixels)
let presentBuffer = UnsafeMutablePointer<UInt16>.allocate(capacity: canvasPixels)

/// Copies the composed frame into the (256-pixel-pitch) back buffer;
/// the canvas is 256 wide, so rows are contiguous halfword copies.
func uploadFrame() {
  var index = 0
  while index < canvasPixels {
    backBuffer[index] = presentBuffer[index]
    index += 1
  }
}

// MARK: - Bottom-screen keyboard

keyboardDemoInit()
keyboardShow()

// MARK: - Search state

/// The typed search filter (ASCII bytes), rendered in the search bar and
/// matched against name/city/address/zip/state like the other platforms.
var query = [UInt8]()
let maxQueryLength = 28

// MARK: - Screens

func makeDetail(_ location: Location) -> Screen {
  var items = [MenuItem]()
  items.append(MenuItem(utf8Bytes(location.address)))
  items.append(MenuItem("City", detail: { utf8Bytes(location.city) }))
  items.append(MenuItem("State", detail: { utf8Bytes(location.state) }))
  items.append(MenuItem("ZIP Code", detail: { utf8Bytes(location.zipCode) }))
  items.append(MenuItem("Phone", detail: { utf8Bytes(location.phone) }))
  items.append(MenuItem("Truck Parking", detail: { intBytes(Int32(location.truckParkingSpaces)) }))
  for product in fuelProducts(for: location) {
    let cents = Int32(product.price * 100 + 0.5)
    items.append(
      MenuItem(
        utf8Bytes(product.descriptionText),
        detail: { priceBytes(cents: cents) }))
  }
  return Screen(title: utf8Bytes(location.name), content: .menu(items))
}

/// The locations list, filtered by the current query through the real
/// CoreModel predicate engine (see Store.swift).
func buildLocationItems() -> [MenuItem] {
  var items = [MenuItem]()
  for location in searchLocations(query) {
    items.append(
      MenuItem(
        utf8Bytes(location.name),
        action: .push { makeDetail(location) },
        detail: { utf8Bytes(location.city) }))
  }
  return items
}

let rootScreen = Screen(
  title: "Fueling",
  content: .menu([MenuItem("Starting up...")]),
  showsSearch: false)

let navigator = Navigator(root: rootScreen)

/// Requested by the error screen's Retry row; serviced in the main loop.
var requestFetch = true

/// Swaps the root screen to the fetched list (search enabled) or an error
/// screen with a Retry row.
func applyFetchResult(_ result: FetchResult) {
  var items = [MenuItem]()
  switch result {
  case .success:
    rootScreen.showsSearch = true
    query.removeAll()
    items = buildLocationItems()
  case .wifiFailed:
    rootScreen.showsSearch = false
    items.append(MenuItem("Wifi connection failed"))
    items.append(MenuItem("Check the emulator's"))
    items.append(MenuItem("internet settings"))
    items.append(MenuItem("Retry", action: .run { requestFetch = true }))
  case .requestFailed:
    rootScreen.showsSearch = false
    items.append(MenuItem("Server unreachable"))
    items.append(MenuItem("Server", detail: { staticBytes(serverHostHeader) }))
    items.append(MenuItem("Failed step", detail: { intBytes(lastHTTPStep) }))
    items.append(MenuItem("errno", detail: { intBytes(lastErrno) }))
    items.append(MenuItem("HTTP status", detail: { intBytes(lastHTTPStatus) }))
    items.append(MenuItem("Retry", action: .run { requestFetch = true }))
  case .parseFailed:
    rootScreen.showsSearch = false
    items.append(MenuItem("Unexpected response"))
    items.append(MenuItem("Retry", action: .run { requestFetch = true }))
  case .storeFailed:
    rootScreen.showsSearch = false
    items.append(MenuItem("Store rejected data"))
    items.append(MenuItem("Retry", action: .run { requestFetch = true }))
  }
  rootScreen.content = .menu(items)
  rootScreen.selection = 0
  rootScreen.scrollOffset = 0
  frameDirty = true
}

/// Re-filters the list after a keystroke, keeping the selection in range.
func queryDidChange() {
  let items = buildLocationItems()
  rootScreen.content = .menu(items)
  let count = Int32(items.count)
  if rootScreen.selection >= count {
    rootScreen.selection = count > 0 ? count - 1 : 0
  }
  rootScreen.scrollOffset = Navigator.scrollOffset(
    selection: rootScreen.selection,
    current: rootScreen.scrollOffset,
    rowCount: count,
    visibleRows: rootScreen.visibleRowCount)
  frameDirty = true
}

// MARK: - Navigation slide state

var slideProgress: Int32 = -1  // -1 = idle, else 0...64
var slidePush = true
var frameDirty = true

func beginSlide(push: Bool) {
  // capture what is currently on screen as the outgoing frame
  var i = 0
  while i < canvasPixels {
    outgoingBuffer[i] = presentBuffer[i]
    i += 1
  }
  slidePush = push
  slideProgress = 0
  frameDirty = true
}

// MARK: - Presenting

/// Draws the top screen synchronously (startup and the blocking fetch).
func presentImmediately() {
  renderScreen(renderCanvas, screen: navigator.top, query: query)
  var i = 0
  while i < canvasPixels {
    presentBuffer[i] = renderCanvas.pixels[i]
    i += 1
  }
  uploadFrame()
  flipBuffers()
}

/// Blocking connect + download, with progress shown on the top screen.
func runFetch() {
  rootScreen.showsSearch = false
  rootScreen.content = .menu([
    MenuItem(wifiConnected ? "Downloading locations..." : "Connecting to wifi..."),
    MenuItem("Server", detail: { staticBytes(serverHostHeader) }),
  ])
  rootScreen.selection = 0
  rootScreen.scrollOffset = 0
  presentImmediately()
  applyFetchResult(fetchAll())
}

// MARK: - Input helpers

func scroll(_ delta: Int32) {
  let screen = navigator.top
  guard case .menu(let items) = screen.content else { return }
  navigator.moveSelection(
    by: delta, rowCount: Int32(items.count), visibleRows: screen.visibleRowCount)
  frameDirty = true
}

func select() {
  guard case .menu(let items) = navigator.top.content else { return }
  let index = Int(navigator.top.selection)
  guard index >= 0, index < items.count else { return }
  switch items[index].action {
  case .none:
    break
  case .run(let action):
    action()
    frameDirty = true
  case .push(let makeScreen):
    beginSlide(push: true)
    navigator.push(makeScreen())
  }
}

func back() {
  if navigator.pop() {
    beginSlide(push: false)
  }
}

/// A key from the bottom-screen keyboard: printable ASCII appends to the
/// query, backspace deletes; only the search screen listens.
func handleKeyboard(_ key: Int32) {
  guard navigator.top.showsSearch else { return }
  if key == 8 {  // backspace
    if !query.isEmpty {
      query.removeLast()
      queryDidChange()
    }
  } else if key >= 32, key <= 126, query.count < maxQueryLength {
    query.append(UInt8(key))
    queryDidChange()
  }
}

// MARK: - Main loop

// key repeat for scrolling: 360ms delay, 60ms interval (in frames)
var heldFrames: Int32 = 0


// first frame
presentImmediately()

/// Flip on the vblank after the upload, never mid-frame.
var pendingFlip = false

while pmMainLoop() {
  threadWaitForVBlank()
  if pendingFlip {
    flipBuffers()
    pendingFlip = false
  }

  // startup fetch / Retry row (blocks the loop while downloading)
  if requestFetch {
    requestFetch = false
    runFetch()
  }

  scanKeys()
  let pressed = keysDown()
  let held = keysHeld()

  if pressed & KEY_START != 0 { break }

  // selection: pressed edges plus a simple hold-to-repeat
  var delta: Int32 = 0
  if pressed & KEY_UP != 0 { delta = -1 }
  if pressed & KEY_DOWN != 0 { delta = 1 }
  if held & (KEY_UP | KEY_DOWN) != 0 {
    heldFrames &+= 1
    if heldFrames > 21, heldFrames % 4 == 0 {
      delta = held & KEY_UP != 0 ? -1 : 1
    }
  } else {
    heldFrames = 0
  }
  if delta != 0 { scroll(delta) }

  if pressed & KEY_A != 0 { select() }
  if pressed & KEY_B != 0 { back() }

  // bottom-screen keyboard (touch handled inside keyboardUpdate)
  let key = keyboardUpdate()
  if key > 0 { handleKeyboard(key) }

  // navigation slide
  if slideProgress >= 0 {
    slideProgress &+= 5
    frameDirty = true
    if slideProgress >= 64 {
      slideProgress = -1
    }
  }

  if frameDirty {
    frameDirty = false
    renderScreen(renderCanvas, screen: navigator.top, query: query)
    if slideProgress >= 0 {
      compositeSlide(
        present: presentBuffer,
        outgoing: outgoingBuffer,
        incoming: renderCanvas.pixels,
        width: screenWidth, height: screenHeight,
        p64: slideProgress, push: slidePush)
    } else {
      var pixel = 0
      while pixel < canvasPixels {
        presentBuffer[pixel] = renderCanvas.pixels[pixel]
        pixel += 1
      }
    }
    uploadFrame()
    pendingFlip = true
  }
}
