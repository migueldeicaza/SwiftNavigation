import Foundation
import CRecast

@available(macOS 13.3.0, *)

/// Mesh that can be navigated
public class NavMesh {
    /// Errors that are surfaced by the Detour API.
    public enum NavMeshError: Error {
        /// Input data is not recognized.
        case wrongMagic
        /// Input data is in wrong version.
        case wrongVersion
        /// Operation ran out of memory.
        case alloc
        /// An input parameter was invalid.
        case invalidParam
        /// Result buffer for the query was too small to store all results.
        case bufferTooSmall
        /// Query ran out of nodes during search.
        case outOfNodes
        /// Query did not reach the end location, returning best guess.
        case partialResult
        /// A tile has already been assigned to the given x,y coordinate
        case alreadyOccupied
        /// A new error that is not handled was produced by Detour
        case unknown
    }
    
    static func statusToError (_ status: dtStatus) -> NavMeshError {
        let v = status & DT_STATUS_DETAIL_MASK
        switch v {
        case DT_WRONG_MAGIC:
            return .wrongMagic
        case DT_WRONG_VERSION:
            return .wrongVersion
        case DT_OUT_OF_MEMORY:
            return .alloc
        case DT_INVALID_PARAM:
            return .invalidParam
        case DT_BUFFER_TOO_SMALL:
            return .bufferTooSmall
        case DT_OUT_OF_NODES:
            return .outOfNodes
        case DT_PARTIAL_RESULT:
            return .partialResult
        case DT_ALREADY_OCCUPIED:
            return .alreadyOccupied
        default:
            return .unknown
        }
    }
    
    var navMesh: dtNavMesh
    
    /// Creates a Detour from a binary blob
    public init (_ blob: Data) throws {
        guard let handle = dtAllocNavMesh() else {
            throw NavMeshError.alloc
        }
        guard var copy = malloc (blob.count) else {
            dtFreeNavMesh(handle)
            throw NavMeshError.alloc
        }
        _ = blob.withUnsafeBytes { ptr in
            memcpy (copy, ptr.baseAddress, blob.count)
        }
        
        let status = handle.`init`(copy, Int32(blob.count), Int32 (DT_TILE_FREE_DATA.rawValue))
        if dtStatusFailed(status) {
            dtFreeNavMesh(handle)
            throw NavMesh.statusToError (status)
        }
        navMesh = handle
    }
    
    init (_ ptr: UnsafeMutableRawPointer, size: Int32) throws {
        guard let handle = dtAllocNavMesh() else {
            throw NavMeshError.alloc
        }
        let status = handle.`init`(ptr, size, Int32 (DT_TILE_FREE_DATA.rawValue))
        if dtStatusFailed(status) {
            dtFreeNavMesh(handle)
            throw NavMesh.statusToError (status)
        }
        navMesh = handle
    }
    
    /// Creates a query object, used to find paths
    /// - Parameters:
    ///  - maxNodes: Maximum number of search nodes. [Limits: 0 < value <= 65535]
    /// - Returns: the nav mesh query, or throws an exception on error.
    public func makeQuery (maxNodes: Int32 = 2048) throws -> NavMeshQuery {
        return try NavMeshQuery(nav: self, maxNodes: maxNodes)
    }
}
