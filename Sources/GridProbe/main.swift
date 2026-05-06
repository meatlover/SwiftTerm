// GridProbe — feed a byte stream into a fresh SwiftTerm `Terminal` and
// dump the resulting grid as plain text. Pure-SwiftTerm isolation
// harness used to bisect display artifacts independently of tmux,
// meatmux's control-mode pipeline, or any GUI.
//
// Usage:  GridProbe <bytes-file> [cols] [rows]
//
// Output: each grid row on a separate line (rstripped), to stdout.
//
// Compare the output to `tmux capture-pane -p` of the same byte stream
// to detect SwiftTerm-vs-tmux divergences without anything else in the
// pipeline.

import Foundation
import SwiftTerm

guard CommandLine.arguments.count >= 2 else {
    FileHandle.standardError.write("usage: GridProbe <bytes-file> [cols=197] [rows=92] [chunk=0]\n".data(using: .utf8)!)
    FileHandle.standardError.write("       chunk=0 means feed entire file in one call (default).\n".data(using: .utf8)!)
    FileHandle.standardError.write("       chunk=N means feed in N-byte slices to simulate %output chunking.\n".data(using: .utf8)!)
    exit(2)
}

let path = CommandLine.arguments[1]
let cols = CommandLine.arguments.count > 2 ? (Int(CommandLine.arguments[2]) ?? 197) : 197
let rows = CommandLine.arguments.count > 3 ? (Int(CommandLine.arguments[3]) ?? 92)  : 92
let chunk = CommandLine.arguments.count > 4 ? (Int(CommandLine.arguments[4]) ?? 0) : 0

guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
    FileHandle.standardError.write("error: cannot read \(path)\n".data(using: .utf8)!)
    exit(2)
}

var opts = TerminalOptions.default
opts.cols = cols
opts.rows = rows
let queue = DispatchQueue(label: "GridProbe", qos: .userInteractive)
let h = HeadlessTerminal(queue: queue, options: opts) { _ in }
let t = h.terminal!
t.silentLog = true

let bytes = [UInt8](data)
if chunk <= 0 {
    t.feed(byteArray: bytes)
} else {
    var i = 0
    while i < bytes.count {
        let end = min(i + chunk, bytes.count)
        let slice = Array(bytes[i..<end])
        t.feed(byteArray: slice)
        i = end
    }
}

// Dump the visible grid using only public APIs. `getCharData(col:row:)` on
// `Terminal` resolves through the active buffer; row is 0..<rows on the
// visible viewport.
for row in 0..<rows {
    var s = ""
    for col in 0..<cols {
        let cd = t.getCharData(col: col, row: row) ?? CharData.Null
        s.append(cd.getCharacter())
    }
    while let last = s.last, last == " " || last == "\0" { s.removeLast() }
    print(s)
}

FileHandle.standardError.write("cursor: col=\(t.buffer.x) row=\(t.buffer.y) cols=\(cols) rows=\(rows)\n".data(using: .utf8)!)
