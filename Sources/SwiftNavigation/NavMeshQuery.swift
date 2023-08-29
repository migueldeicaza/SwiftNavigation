//
// Binding to the NavMeshQuery
//
import Foundation
import CRecast

/// Represents a point inside a polygon reference, bound to the mesh
///
/// Various routines in SwiftNavigation are optimized to use both a polygon reference
/// and a location, and this structure can be used to pass both values around.
public struct PointInPoly: CustomDebugStringConvertible {
    /// Polygon reference
    public let polyRef: dtPolyRef
    /// Point in the polygon stored in an array of three floats (x, y, z)
    public let point: [Float]
    /// Point in the polygon as a SIMD3 value
    public var point3: SIMD3<Float> {
        return [point [0], point [1], point [2]]
    }
    
    /// Produces an informational string with the polygon reference and the location in space
    public var debugDescription: String {
        return "[\(polyRef):\(point3)]"
    }
}

/// NavMeshQuery is used to perform path finding queries in the ``NavMesh`` and is created
/// by calling the ``NavMesh/makeQuery(maxNodes:)`` method.   That sets up some
/// costly internal data structures.
///
/// Then you can call methods like ``findRandomPoint(filter:randomFunction:)``, ``findPathCorridor(filter:start:end:maxPaths:)`` or ``findStraightPath(filter:startPos:endPos:pathCorridor:maxPaths:options:)``.
///
public class NavMeshQuery {
    public enum NavMeshQueryError: Error {
        /// Failed to allocate memory
        case alloc
        /// Failed to initialize the dtNavMeshQuery
        case navInit
    }
    var query: dtNavMeshQuery
    var filter: NavQueryFilter

    /// - Parameters:
    ///   - nav: the navigation mesh this will operate on
    ///   - maxNodes: Maximum number of search nodes. [Limits: 0 < value <= 65535]
    init (nav: NavMesh, maxNodes: Int32 = 2048) throws {
        guard let query = dtAllocNavMeshQuery() else {
            throw NavMeshQueryError.alloc
        }
        let status = query.`init`(nav.navMesh, maxNodes)
        if dtStatusFailed(status) {
            dtFreeNavMeshQuery(query)
            throw NavMeshQueryError.navInit
        }
        filter = NavQueryFilter ()
        self.query = query
    }
    
    /// Gets a random point in the mesh, using an optional filter, and returns the
    /// - Parameters:
    ///  - filter: an optional filter to determine the elegibility of a polygon
    ///  - randomFunction: optional, if specified, it is a function that returns a value in the range `0..<1`
    /// - Returns: the PointInPoly or a NavMeshError on failure
    public func findRandomPoint (filter custom: NavQueryFilter? = nil, randomFunction: (@convention(c) () -> Float)? = nil) -> Result<PointInPoly,NavMesh.NavMeshError> {
        var polyRef: dtPolyRef = 0
        var point: [Float] = [0, 0, 0]
        
        let res = query.findRandomPoint((custom ?? self.filter).query, randomFunction ?? floatRand, &polyRef, &point)
        if dtStatusSucceed(res) {
            return .success(PointInPoly(polyRef: polyRef, point: point))
        }
        return .failure (NavMesh.statusToError(res))
    }
    
    /// Finds a path corridor in term of polygon references from the start polygon to the end polygon.
    ///
    /// If the end polygon cannot be reached through the navigation graph,
    /// the last polygon in the path will be the nearest the end polygon.
    ///
    /// If the path array is to small to hold the full result, it will be filled as
    /// far as possible from the start polygon toward the end polygon.
    ///
    /// The start and end positions are used to calculate traversal costs.
    /// (The y-values impact the result.)
    /// - Parameters:
    ///  - filter: an optional filter to determine the elegibility of a polygon
    ///  - start: initial starting point
    ///  - end: end point
    ///  - maxPaths: the maximum number of paths to generate
    /// - Returns: on success, an array of polygon references from the starting point to the ending point, on failure, a detail for the reason why the path could not be found
    public func findPathCorridor (filter custom: NavQueryFilter? = nil, start: PointInPoly, end: PointInPoly, maxPaths: Int = 512) -> Result<[dtPolyRef],NavMesh.NavMeshError> {
        var result: [dtPolyRef] = Array.init(repeating: 0, count: maxPaths)
        var count: Int32 = 0
        
        var startPoint = start.point
        var endPoint = end.point
        
        let res = query.findPath(start.polyRef, end.polyRef, &startPoint, &endPoint, (custom ?? self.filter).query, &result, &count, Int32(maxPaths))
        
        if dtStatusSucceed(res) {
            if result.count != count {
                result.removeSubrange(Int(count)..<result.count)
            }
            return .success(result)
        }
        return .failure(NavMesh.statusToError(res))
    }
    
    public struct StraightPathOptions: OptionSet {
        public init (rawValue: Int32) {
            self.rawValue = rawValue
        }
        
        public let rawValue: Int32
        /// Add a vertex at every polygon edge crossing where area changes.
        public static let areaCrossings = StraightPathOptions(rawValue: Int32(DT_STRAIGHTPATH_AREA_CROSSINGS.rawValue))
        /// Add a vertex at every polygon edge crossing.
        public static let allCrossings = StraightPathOptions(rawValue: Int32(DT_STRAIGHTPATH_ALL_CROSSINGS.rawValue))
    }
    
    public struct StraightPathFlags: OptionSet, CustomStringConvertible {
        public init (rawValue: UInt8) {
            self.rawValue = rawValue
        }
        init (v: dtStraightPathFlags) {
            self.rawValue = UInt8(v.rawValue)
        }
        public let rawValue: UInt8
        
        /// The vertex is the start position in the path.
        public static let start = StraightPathFlags (v: DT_STRAIGHTPATH_START)
        
        /// The vertex is the end position in the path.
        public static let end = StraightPathFlags (v: DT_STRAIGHTPATH_END)
        
        /// The vertex is the start of an off-mesh connection.
        public static let offMeshConnection = StraightPathFlags (v: DT_STRAIGHTPATH_OFFMESH_CONNECTION)
        
        static var debugDescriptions: [(Self, String)] = [
               (.start, ".start"),
               (.end, ".end"),
               (.offMeshConnection, ".offMeshConnection"),
           ]

           public var description: String {
               return "[\(Self.debugDescriptions.filter { contains($0.0) }.map { $0.1 }.joined(separator: ","))]"
           }
    }
    
    /// Finds the straight path from the start to the end position within the polygon corridor.
    ///
    /// This method peforms what is often called 'string pulling'.
    ///
    /// The start position is clamped to the first polygon in the path, and the
    /// end position is clamped to the last. So the start and end positions should
    /// normally be within or very near the first and last polygons respectively.
    ///
    /// The returned polygon references represent the reference id of the polygon
    /// that is entered at the associated path position. The reference id associated
    /// with the end point will always be zero.  This allows, for example, matching
    /// off-mesh link points to their representative polygons.
    ///
    /// If the provided result buffers are too small for the entire result set,
    /// they will be filled as far as possible from the start toward the end
    /// position.
    ///
    /// - Parameters:
    ///  - filter: an optional filter to determine the elegibility of a polygon
    ///  - startPos: the starting position as a floating point array containing (x, y, z) values
    ///  - endPos: the ending position as a floating point array containing (x, y, z) values
    ///  - pathCorridor: an array of dtPolyRefs that obtained from ``findPathCorridor(filter:start:end:maxPaths:)`` that contains the polygons to traverse
    ///  - maxPaths: the maximum number of points to return
    ///  - options: options controlling which vertices to add.
    public func findStraightPath (filter custom: NavQueryFilter? = nil, startPos: SIMD3<Float>, endPos: SIMD3<Float>, pathCorridor: [dtPolyRef], maxPaths: Int = 512, options: StraightPathOptions = []) -> Result<FoundPath, NavMesh.NavMeshError> {
        
        var _startPos: [Float] = [startPos.x, startPos.y, startPos.z]
        var _endPos: [Float] = [endPos.x, endPos.y, endPos.z]
        var _pathCorridor = pathCorridor
        
        // Allocate the result array
        var resultStraightPath: [Float] = Array.init(repeating: 3.2, count: 3*maxPaths)
        var resultFlags: [StraightPathFlags] = Array.init(repeating: StraightPathFlags(rawValue: 0xbb), count: maxPaths)
        var resultRefs: [dtPolyRef] = Array.init(repeating: 0x99, count: maxPaths)
        var resultCount: Int32 = 0
        
        let res = resultFlags.withUnsafeMutableBufferPointer { rFlagsPtr in
            query.findStraightPath(&_startPos, &_endPos, &_pathCorridor, Int32(_pathCorridor.count), &resultStraightPath, rFlagsPtr.baseAddress, &resultRefs, &resultCount, Int32(maxPaths), options.rawValue)
        }
        
        if dtStatusSucceed(res) {
            if resultStraightPath.count != resultCount {
                resultStraightPath.removeSubrange(Int(resultCount*3)..<3*maxPaths)
                resultFlags.removeSubrange(Int(resultCount)..<maxPaths)
                resultRefs.removeSubrange(Int(resultCount)..<maxPaths)
            }
            return .success(FoundPath(count: Int(resultCount), rawPathPoints: resultStraightPath, flags: resultFlags, polyRefs: resultRefs))
        }
        return .failure(NavMesh.statusToError(res))
    }
    
    /// Finds the straight path from the start to the end position, computing the path corridor implicitly.
    ///
    /// This method is a convenience that calls ``findPathCorridor(filter:start:end:maxPaths:)`` followed
    /// by calling ``findStraightPath(filter:startPos:endPos:pathCorridor:maxPaths:options:)``.
    /// 
    /// This method peforms what is often called 'string pulling'.
    ///
    /// The start position is clamped to the first polygon in the path, and the
    /// end position is clamped to the last. So the start and end positions should
    /// normally be within or very near the first and last polygons respectively.
    ///
    /// The returned polygon references represent the reference id of the polygon
    /// that is entered at the associated path position. The reference id associated
    /// with the end point will always be zero.  This allows, for example, matching
    /// off-mesh link points to their representative polygons.
    ///
    /// If the provided result buffers are too small for the entire result set,
    /// they will be filled as far as possible from the start toward the end
    /// position.
    ///
    /// - Parameters:
    ///  - filter: an optional filter to determine the elegibility of a polygon
    ///  - startPos: the starting position as a PointInPoly location.
    ///  - endPos: the ending position as a PointInPoly location.
    ///  - maxPaths: the maximum number of points to return
    ///  - options: options controlling which vertices to add.
    public func findStraightPath (filter custom: NavQueryFilter? = nil, startPos: PointInPoly, endPos: PointInPoly, maxPaths: Int = 512, options: StraightPathOptions = []) -> Result<FoundPath, NavMesh.NavMeshError> {
        switch findPathCorridor(filter: custom, start: startPos, end: endPos, maxPaths: maxPaths) {
        case .failure(let err):
            return .failure(err)
        case .success(let corridor):
            return findStraightPath(filter: filter, startPos: startPos.point3, endPos: endPos.point3, pathCorridor: corridor, maxPaths: maxPaths, options: options)
        }
    }
    
    /// Contains the resulting value for calling ``findStraightPath(filter:startPos:endPos:pathCorridor:maxPaths:options:)``
    /// The arrays are guaranteed to contains the same elements (path is 3 times larger, due to having 3 floating point values)
    public struct FoundPath {
        /// The number of items in the found value.
        public var count: Int
        /// Array of floating point values, containing 3 floating point values per item (x, y and z), use the indexer to retrieve the value as SIMD3<Float>
        public let rawPathPoints: [Float]
        /// Flag for each element in the path, the values are
        public let flags: [StraightPathFlags]
        /// Polygon references
        public let polyRefs: [dtPolyRef]
        
        public subscript (idx: Int) -> SIMD3<Float> {
            if idx > count {
                fatalError("Out of range \(idx) maxValue is \(count)")
            }
            let base = idx * 3
            return SIMD3<Float> (rawPathPoints [base], rawPathPoints[base+1], rawPathPoints [base+2])
        }
    }
    
    /// Finds the polygon nearest to the specified center point.
    /// - Parameters:
    ///   - point: Center of the search box
    ///   - extents: The search distance along each axis.  Defaults to `(1, 1, 1)`
    ///  - filter: an optional filter to determine the elegibility of a polygon
    /// - Returns: On success, the tuple return contains the PointInPoly result, as well as a boolean `isOverPoly`
    ///   that is set to true if the point's X/Z coordinate lies inside the polygon, false otherwise. Unchanged if no polygon is found. 
    public func findNearestPoint (point: SIMD3<Float>, extents: SIMD3<Float> = [1, 1, 1], filter: NavQueryFilter? = nil) -> Result<(PointInPoly,isOverPoly: Bool),NavMesh.NavMeshError>  {
        
        var _point: [Float] = [point.x, point.y, point.z]
        var _extents: [Float] = [extents.x, extents.y, extents.z]
        var nearestRef: dtPolyRef = 0
        var nearestPt: [Float] = [0, 0, 0]
        var isOverPoly: Bool = false
        
        // Should we expose the overload that has isOverPoly?
        let ret = query.findNearestPoly(&_point, &_extents, (filter ?? self.filter).query, &nearestRef, &nearestPt, &isOverPoly)
        if dtStatusSucceed(ret) {
            return .success((PointInPoly (polyRef: nearestRef, point: nearestPt), isOverPoly))
        }
        return .failure(NavMesh.statusToError(ret))
    }
}

func floatRand () -> Float {
    return Float.random(in: 0..<1)
}
