//
//  Utilities.swift
//  
//
//  Created by Miguel de Icaza on 8/28/23.
//

import Foundation

/// Performs buffered output on a FileHandle, you invoke it like this:
/// ```
/// let x = FileHandle(forWritingAtPath: "/tmp/foo")
/// bufferedWriter (on: x) { writer in
///     for x in 0..<1000 {
///        writer ("\(i)")
///     }
/// }
/// ```
func bufferedWriter (on handle: FileHandle, bufferSize: Int = 16*1024, body: (_ : ((String)throws->Void))throws->Void) throws {
    var buffer: [UInt8] = []
    buffer.reserveCapacity(bufferSize)

    
    func writeFunc (_ s: String) throws {
        buffer.append (contentsOf: s.utf8)
        if buffer.count >= bufferSize {
            try handle.write (contentsOf: buffer)
            buffer.removeAll(keepingCapacity: true)
        }
    }
    try body (writeFunc)
    
    // Write the final buffer
    try handle.write(contentsOf: buffer)
}

func export (vertices: [SIMD3<Float>], triangles: [UInt32], to: String) throws {
    enum ExportError: Error {
        case ioError
    }

    FileManager.default.createFile(atPath: to, contents: nil)
    guard let handle = FileHandle(forWritingAtPath: to) else {
        throw ExportError.ioError
    }
    try bufferedWriter(on: handle) { writer in
        for vertix in vertices {
            try writer ("v \(vertix.x) \(vertix.y) \(vertix.z)\n")
        }
        for idx in stride(from: 0, to: triangles.count, by: 3) {
            try writer ("f \(triangles [idx]+1) \(triangles[idx+1]+1) \(triangles[idx+2]+1)\n")
        }
    }
}

