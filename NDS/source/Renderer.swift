//---------------------------------------------------------------------------------
//
//  Renderer.swift -- software rasterizer for the Fueling DS screen.
//
//  Copied from ClassicUI's ports/NDS renderer (branch feature/nds) and
//  trimmed to what this app draws: status bar, search bar, menu rows with
//  right-aligned detail values, selection gradient, chevrons, scrollbar,
//  and the push/pop slide composite. Draws into a 16bpp ARGB1555 row-major
//  canvas (bit 15 set = opaque, the DS's bitmap-background format);
//  main.swift copies the canvas into the 16bpp bitmap background's VRAM
//  on the *top* screen (the bottom screen hosts the keyboard).
//
//  Deliberately imports nothing (no NDS): the same file compiles on the
//  host for snapshot verification.
//
//---------------------------------------------------------------------------------

// MARK: - Canvas

struct Canvas {
  var pixels: UnsafeMutablePointer<UInt16>
  var width: Int32
  var height: Int32

  @inline(__always)
  func set(_ x: Int32, _ y: Int32, _ color: UInt16) {
    guard x >= 0, x < width, y >= 0, y < height else { return }
    pixels[Int(y &* width &+ x)] = color
  }
}

// MARK: - Colors (ARGB1555: red in the low bits, bit 15 = opaque)

@inline(__always)
func rgb15(_ r: Int32, _ g: Int32, _ b: Int32) -> UInt16 {
  let r5 = UInt16((r &* 31) / 255) & 0x1F
  let g5 = UInt16((g &* 31) / 255) & 0x1F
  let b5 = UInt16((b &* 31) / 255) & 0x1F
  return 0x8000 | (b5 << 10) | (g5 << 5) | r5
}

// Theme colors (ClassicUI's classic look).
let colorBackground = rgb15(255, 255, 255)
let colorText = rgb15(0, 0, 0)
let colorSelectedText = rgb15(255, 255, 255)
let colorSeparator = rgb15(115, 115, 120)
let colorDetailText = rgb15(115, 115, 120)
let colorScrollTrack = rgb15(217, 217, 222)
let colorScrollThumb = rgb15(115, 115, 128)
let colorBatteryGreen = rgb15(89, 199, 71)
let colorSearchField = rgb15(240, 240, 244)
let statusGradientTop: (Int32, Int32, Int32) = (250, 250, 250)
let statusGradientBottom: (Int32, Int32, Int32) = (191, 191, 196)
let selectionGradientTop: (Int32, Int32, Int32) = (107, 173, 242)
let selectionGradientBottom: (Int32, Int32, Int32) = (13, 89, 217)

// Metrics (ClassicUI's Theme, adjusted for the DS's 256x192 panel).
let statusBarHeight: Int32 = 20
let searchBarHeight: Int32 = 20
let rowHeight: Int32 = 24
let horizontalPadding: Int32 = 6
let screenWidth: Int32 = 256
let screenHeight: Int32 = 192
/// Menu rows visible without a search bar.
let visibleRows: Int32 = (screenHeight - statusBarHeight) / rowHeight
/// Menu rows visible below the search bar.
let visibleRowsWithSearch: Int32 = (screenHeight - statusBarHeight - searchBarHeight) / rowHeight

// MARK: - Primitives

func fillRect(_ canvas: Canvas, x: Int32, y: Int32, width: Int32, height: Int32, color: UInt16) {
  let x0 = max(0, x), y0 = max(0, y)
  let x1 = min(canvas.width, x &+ width), y1 = min(canvas.height, y &+ height)
  guard x0 < x1, y0 < y1 else { return }
  var dy = y0
  while dy < y1 {
    let row = canvas.pixels + Int(dy &* canvas.width)
    var dx = x0
    while dx < x1 {
      row[Int(dx)] = color
      dx &+= 1
    }
    dy &+= 1
  }
}

/// Vertical gradient with the classic glossy top half (lightened toward
/// white), one band per scanline.
func fillVerticalGradient(
  _ canvas: Canvas, x: Int32, y: Int32, width: Int32, height: Int32,
  top: (Int32, Int32, Int32), bottom: (Int32, Int32, Int32), gloss: Bool
) {
  guard height > 0 else { return }
  var row: Int32 = 0
  while row < height {
    let t = height > 1 ? (row &* 64) / (height &- 1) : 0
    var r = top.0 &+ ((bottom.0 &- top.0) &* t) / 64
    var g = top.1 &+ ((bottom.1 &- top.1) &* t) / 64
    var b = top.2 &+ ((bottom.2 &- top.2) &* t) / 64
    if gloss, row < height / 2 {
      // ~20% toward white, like the desktop renderer's gloss overlay
      r = r &+ (255 &- r) / 5
      g = g &+ (255 &- g) / 5
      b = b &+ (255 &- b) / 5
    }
    fillRect(canvas, x: x, y: y &+ row, width: width, height: 1, color: rgb15(r, g, b))
    row &+= 1
  }
}

// MARK: - Text (see tools/gen_font.py)

/// Alpha-blends `color` over `dst` at 8-bit `coverage` (ARGB1555 channels).
@inline(__always)
func blend555(_ dst: UInt16, _ color: UInt16, _ coverage: Int32) -> UInt16 {
  let dr = Int32(dst & 0x1F)
  let dg = Int32((dst >> 5) & 0x1F)
  let db = Int32((dst >> 10) & 0x1F)
  let sr = Int32(color & 0x1F)
  let sg = Int32((color >> 5) & 0x1F)
  let sb = Int32((color >> 10) & 0x1F)
  let r = dr &+ ((sr &- dr) &* coverage) / 255
  let g = dg &+ ((sg &- dg) &* coverage) / 255
  let b = db &+ ((sb &- db) &* coverage) / 255
  return 0x8000 | (UInt16(b) << 10) | (UInt16(g) << 5) | UInt16(r)
}

/// Draws one run of ASCII bytes; returns the x after the last glyph.
@discardableResult
func drawBytes(
  _ canvas: Canvas, _ bytes: UnsafePointer<UInt8>, _ count: Int32,
  x: Int32, y: Int32, color: UInt16, maxX: Int32 = Int32.max
) -> Int32 {
  var penX = x
  var i: Int32 = 0
  while i < count {
    var code = Int32(bytes[Int(i)])
    if code < fontFirstCode || code > fontLastCode { code = 63 }  // '?'
    let glyph = Int32(code - fontFirstCode)
    let width = fontGlyphWidths[Int(glyph)]
    if penX &+ width > maxX { break }
    let glyphBase = glyph &* fontGlyphHeight &* fontGlyphRowStride
    var gy: Int32 = 0
    while gy < fontGlyphHeight {
      let destY = y &+ gy
      let rowBase = Int(glyphBase &+ gy &* fontGlyphRowStride)
      // draw one column past the advance so antialiased right edges
      // (which spill into the next cell) aren't clipped off
      let drawWidth = min(width &+ 1, fontGlyphRowStride)
      var gx: Int32 = 0
      while gx < drawWidth {
        let coverage = Int32(fontGlyphPixels[rowBase + Int(gx)])
        if coverage != 0 {
          let destX = penX &+ gx
          if destX >= 0, destX < canvas.width, destY >= 0, destY < canvas.height {
            let index = Int(destY &* canvas.width &+ destX)
            canvas.pixels[index] =
              coverage >= 255
              ? color
              : blend555(canvas.pixels[index], color, coverage)
          }
        }
        gx &+= 1
      }
      gy &+= 1
    }
    penX &+= width
    i &+= 1
  }
  return penX
}

@discardableResult
func drawText(
  _ canvas: Canvas, _ text: StaticString, x: Int32, y: Int32, color: UInt16,
  maxX: Int32 = Int32.max
) -> Int32 {
  text.withUTF8Buffer { buffer in
    guard let base = buffer.baseAddress else { return x }
    return drawBytes(canvas, base, Int32(buffer.count), x: x, y: y, color: color, maxX: maxX)
  }
}

/// Draws a runtime byte-array string (the typed search text).
@discardableResult
func drawByteArray(
  _ canvas: Canvas, _ bytes: [UInt8], x: Int32, y: Int32, color: UInt16,
  maxX: Int32 = Int32.max
) -> Int32 {
  bytes.withUnsafeBufferPointer { buffer in
    guard let base = buffer.baseAddress, buffer.count > 0 else { return x }
    return drawBytes(canvas, base, Int32(buffer.count), x: x, y: y, color: color, maxX: maxX)
  }
}

func measureBytes(_ bytes: UnsafePointer<UInt8>, _ count: Int32) -> Int32 {
  var width: Int32 = 0
  var i: Int32 = 0
  while i < count {
    var code = Int32(bytes[Int(i)])
    if code < fontFirstCode || code > fontLastCode { code = 63 }
    width &+= fontGlyphWidths[Int(code - fontFirstCode)]
    i &+= 1
  }
  return width
}

func measure(_ text: StaticString) -> Int32 {
  text.withUTF8Buffer { buffer in
    guard let base = buffer.baseAddress else { return 0 }
    return measureBytes(base, Int32(buffer.count))
  }
}

func measureByteArray(_ bytes: [UInt8]) -> Int32 {
  bytes.withUnsafeBufferPointer { buffer in
    guard let base = buffer.baseAddress, buffer.count > 0 else { return 0 }
    return measureBytes(base, Int32(buffer.count))
  }
}

/// Draws a decimal integer; returns the x after the last digit.
@discardableResult
func drawInt(_ canvas: Canvas, _ value: Int32, x: Int32, y: Int32, color: UInt16) -> Int32 {
  var digits = [UInt8]()
  var v = value
  if v < 0 {
    digits.append(45)  // '-'
    v = -v
  }
  var stack = [UInt8]()
  repeat {
    stack.append(UInt8(48 &+ v % 10))
    v /= 10
  } while v > 0
  while let d = stack.popLast() {
    digits.append(d)
  }
  return digits.withUnsafeBufferPointer { buffer in
    drawBytes(canvas, buffer.baseAddress!, Int32(buffer.count), x: x, y: y, color: color)
  }
}

/// "$D.CC" price bytes from a cents value (no Foundation formatters here).
func priceBytes(cents: Int32) -> [UInt8] {
  var bytes = [UInt8]()
  bytes.append(36)  // '$'
  var dollars = cents / 100
  let remainder = cents % 100
  var stack = [UInt8]()
  repeat {
    stack.append(UInt8(48 &+ dollars % 10))
    dollars /= 10
  } while dollars > 0
  while let d = stack.popLast() { bytes.append(d) }
  bytes.append(46)  // '.'
  bytes.append(UInt8(48 &+ remainder / 10))
  bytes.append(UInt8(48 &+ remainder % 10))
  return bytes
}

/// Text y that vertically centers the glyph box in a row of `height` at `y`.
@inline(__always)
func textTop(rowY: Int32, rowHeight height: Int32) -> Int32 {
  rowY &+ (height &- fontGlyphHeight) / 2 &+ 1
}

// MARK: - Chrome

func drawStatusBar(_ canvas: Canvas, title: [UInt8]) {
  fillVerticalGradient(
    canvas, x: 0, y: 0, width: canvas.width, height: statusBarHeight,
    top: statusGradientTop, bottom: statusGradientBottom, gloss: true)
  fillRect(canvas, x: 0, y: statusBarHeight - 1, width: canvas.width, height: 1, color: colorSeparator)

  let titleWidth = measureByteArray(title)
  drawByteArray(
    canvas, title, x: (canvas.width - titleWidth) / 2,
    y: textTop(rowY: 0, rowHeight: statusBarHeight), color: colorText)

  // battery
  let batteryRight = canvas.width - 4
  fillRect(canvas, x: batteryRight - 17, y: 5, width: 17, height: 9, color: colorSeparator)
  fillRect(canvas, x: batteryRight - 19, y: 8, width: 2, height: 4, color: colorSeparator)
  fillRect(canvas, x: batteryRight - 16, y: 6, width: 15, height: 7, color: colorBatteryGreen)
}

/// The search field row under the status bar: typed text, or a gray
/// placeholder when empty, with a caret. Fed by the bottom-screen keyboard.
func drawSearchBar(_ canvas: Canvas, query: [UInt8]) {
  let y = statusBarHeight
  fillRect(canvas, x: 0, y: y, width: canvas.width, height: searchBarHeight, color: colorSearchField)
  fillRect(canvas, x: 0, y: y &+ searchBarHeight - 1, width: canvas.width, height: 1, color: colorSeparator)

  let textY = textTop(rowY: y, rowHeight: searchBarHeight)
  var caretX: Int32
  if query.isEmpty {
    drawText(canvas, "Search", x: horizontalPadding, y: textY, color: colorDetailText)
    caretX = horizontalPadding
  } else {
    caretX = drawByteArray(
      canvas, query, x: horizontalPadding, y: textY, color: colorText,
      maxX: canvas.width - horizontalPadding)
    caretX &+= 1
  }
  // caret
  fillRect(canvas, x: caretX, y: y &+ 3, width: 1, height: searchBarHeight - 6, color: colorSeparator)
}

func drawChevron(_ canvas: Canvas, right: Int32, centerY: Int32, color: UInt16) {
  var i: Int32 = 0
  while i < 5 {
    canvas.set(right - 5 &+ i, centerY - 4 &+ i, color)
    canvas.set(right - 6 &+ i, centerY - 4 &+ i, color)
    canvas.set(right - 5 &+ i, centerY + 4 &- i, color)
    canvas.set(right - 6 &+ i, centerY + 4 &- i, color)
    i &+= 1
  }
}

func drawScrollBar(
  _ canvas: Canvas, top: Int32, rowCount: Int32, visibleCount: Int32, scrollOffset: Int32
) {
  let x = canvas.width - 8
  let trackY = top
  let trackHeight = canvas.height - top
  fillRect(canvas, x: x, y: trackY, width: 8, height: trackHeight, color: colorScrollTrack)
  fillRect(canvas, x: x, y: trackY, width: 1, height: trackHeight, color: colorSeparator)
  guard rowCount > visibleCount else { return }
  let usable = trackHeight - 4
  var thumbHeight = (usable &* visibleCount) / rowCount
  if thumbHeight < 8 { thumbHeight = 8 }
  let maxOffset = rowCount - visibleCount
  let thumbY = trackY &+ 2 &+ ((usable &- thumbHeight) &* scrollOffset) / maxOffset
  fillRect(canvas, x: x + 2, y: thumbY, width: 4, height: thumbHeight, color: colorScrollThumb)
}

// MARK: - Screen rendering

func renderScreen(_ canvas: Canvas, screen: Screen, query: [UInt8]) {
  fillRect(canvas, x: 0, y: 0, width: canvas.width, height: canvas.height, color: colorBackground)
  drawStatusBar(canvas, title: screen.title)
  if screen.showsSearch {
    drawSearchBar(canvas, query: query)
  }
  if case .menu(let items) = screen.content {
    renderMenu(canvas, screen: screen, items: items)
  }
}

private func renderMenu(_ canvas: Canvas, screen: Screen, items: [MenuItem]) {
  let listTop = statusBarHeight &+ (screen.showsSearch ? searchBarHeight : 0)
  let visible = screen.showsSearch ? visibleRowsWithSearch : visibleRows
  let count = Int32(items.count)
  let showsScrollBar = count > visible
  let rowWidth = showsScrollBar ? canvas.width - 8 : canvas.width

  if count == 0, screen.showsSearch {
    drawText(
      canvas, "No locations found", x: horizontalPadding,
      y: textTop(rowY: listTop &+ 4, rowHeight: rowHeight), color: colorDetailText)
    return
  }

  var slot: Int32 = 0
  while slot < visible, screen.scrollOffset &+ slot < count {
    let index = screen.scrollOffset &+ slot
    let item = items[Int(index)]
    let y = listTop &+ slot &* rowHeight
    let selected = index == screen.selection

    if selected {
      fillVerticalGradient(
        canvas, x: 0, y: y, width: rowWidth, height: rowHeight,
        top: selectionGradientTop, bottom: selectionGradientBottom, gloss: true)
    }

    let textColor = selected ? colorSelectedText : colorText
    let textY = textTop(rowY: y, rowHeight: rowHeight)
    var maxX = rowWidth - horizontalPadding
    if item.isNavigation { maxX -= 14 }

    if let detail = item.detail {
      let value = detail()
      let valueWidth = value.withUnsafeBufferPointer { buffer -> Int32 in
        guard let base = buffer.baseAddress else { return 0 }
        return measureBytes(base, Int32(buffer.count))
      }
      drawByteArray(
        canvas, value, x: maxX - valueWidth, y: textY,
        color: selected ? colorSelectedText : colorDetailText)
      maxX -= valueWidth &+ 8
    }

    drawByteArray(canvas, item.title, x: horizontalPadding, y: textY, color: textColor, maxX: maxX)

    if item.isNavigation {
      drawChevron(canvas, right: rowWidth - horizontalPadding, centerY: y &+ rowHeight / 2, color: textColor)
    }
    slot &+= 1
  }

  if showsScrollBar {
    drawScrollBar(
      canvas, top: listTop, rowCount: count, visibleCount: visible,
      scrollOffset: screen.scrollOffset)
  }
}

// MARK: - Navigation slide (ClassicUI's push/pop composite)

/// Composites `outgoing` and `incoming` side by side at eased progress
/// `p64` (0...64) into `present`. Push slides in from the right, pop from
/// the left; the status bar stays pinned to the incoming screen.
func compositeSlide(
  present: UnsafeMutablePointer<UInt16>,
  outgoing: UnsafePointer<UInt16>,
  incoming: UnsafePointer<UInt16>,
  width: Int32, height: Int32, p64: Int32, push: Bool
) {
  // ease-out: 64 - (64-p)^2/64
  let inverted = 64 - p64
  let eased = 64 - (inverted &* inverted) / 64
  var offset = (width &* eased) / 64
  if offset < 0 { offset = 0 }
  if offset > width { offset = width }

  var y: Int32 = 0
  while y < height {
    let rowStart = Int(y &* width)
    if y < statusBarHeight {
      // pinned status bar, always the incoming screen's
      var x = 0
      while x < Int(width) {
        present[rowStart + x] = incoming[rowStart + x]
        x += 1
      }
    } else if push {
      // outgoing slides left, incoming enters from the right
      var x: Int32 = 0
      while x < width {
        let source = x &+ offset
        present[rowStart + Int(x)] =
          source < width
          ? outgoing[rowStart + Int(source)]
          : incoming[rowStart + Int(source &- width)]
        x &+= 1
      }
    } else {
      // incoming enters from the left, outgoing slides right
      var x: Int32 = 0
      while x < width {
        present[rowStart + Int(x)] =
          x < offset
          ? incoming[rowStart + Int(width &- offset &+ x)]
          : outgoing[rowStart + Int(x &- offset)]
        x &+= 1
      }
    }
    y &+= 1
  }
}
