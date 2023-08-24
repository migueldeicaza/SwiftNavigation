//
//  SwiftRecast.swift
//  
//
//  Created by Miguel de Icaza on 8/21/23.
//

import Foundation
import CRecast

/// Creates a navigational mesh based on a geometry provided by vertices and triangles
///
/// The constructor takes both your data and a configuration object with various settings
/// that describe the kind of mesh that you want to create.   The configuration object
/// contains various defaults already set which should work for most situations.
///
public class NavMeshBuilder {
    /// The possible styles for partitioning the heightfield
    public enum PartitionStyle: Int32 {
        /// - the classic Recast partitioning
        /// - creates the nicest tessellation
        /// - usually slowest
        /// - partitions the heightfield into nice regions without holes or overlaps
        /// - the are some corner cases where this method creates produces holes and overlaps
        ///    - holes may appear when a small obstacles is close to large open area (triangulation can handle this)
        ///    - overlaps may occur if you have narrow spiral corridors (i.e stairs), this make triangulation to fail
        /// * generally the best choice if you precompute the navmesh, use this if you have large open areas
        case watershed
        /// - fastest
        /// - partitions the heightfield into regions without holes and overlaps (guaranteed)
        /// - creates long thin polygons, which sometimes causes paths with detours
        /// * use this if you want fast navmesh generation
        case monotone
        /// - quite fast
        /// - partitions the heighfield into non-overlapping regions
        /// - relies on the triangulation code to cope with holes (thus slower than monotone partitioning)
        /// - produces better triangles than monotone partitioning
        /// - does not have the corner cases of watershed partitioning
        /// - can be slow and create a bit ugly tessellation (still better than monotone)
        ///   if you have large open areas with small obstacles (not a problem if you use tiles)
        /// * good choice to use for tiled navmesh with medium and small sized tiles
        case layer
    }
    
    /// Specifies a configuration to use when performing Recast builds.
    /// The is a convenience structure that represents an aggregation of parameters
    /// used at different stages in the Recast build process. Some
    /// values are derived during the build process. Not all parameters
    /// are used for all build processes.
    ///
    /// Units are usually in voxels (vx) or world units (wu).  The units for voxels,
    /// grid size, and cell size are all based on the values of #cs and #ch.
    ///
    /// In this documentation, the term 'field' refers to heightfield and
    /// contour data structures that define spacial information using an integer
    /// grid.
    ///
    /// The upper and lower limits for the various parameters often depend on
    /// the platform's floating point accuraccy as well as interdependencies between
    /// the values of multiple parameters.  See the individual parameter
    /// documentation for details.
    ///
    /// First you should decide the size of your agent's logical cylinder.
    /// If your game world uses meters as units, a reasonable starting point for
    /// a human-sized agent might be a radius of `0.4` and a height of `2.0`.
    ///
    public struct Config
    {
        /// The width of the field along the x-axis. [Limit: >= 0] [Units: vx]
        /// Optional, if not set, it gets computed from the boundaries and cellSize
        public var width: Int32?
        
        /// The height of the field along the z-axis. [Limit: >= 0] [Units: vx]
        /// Optional, if not set, it gets computed from the boundaries and cellSize
        public var height: Int32?
        
        /// The width/height size of tile's on the xz-plane. [Limit: >= 0] [Units: vx]
        /// This field is only used when building multi-tile meshes.
        public var tileSize: Int32
        
        /// The size of the non-navigable border around the heightfield. [Limit: >=0] [Units: vx]
        /// This value represents the the closest the walkable area of the heightfield
        /// should come to the xz-plane AABB of the field. It does not have any
        /// impact on the borders around internal obstructions.
        ///
        /// If not set, the borderSize is calculated as ``walkableRadius`` + 3
        public var borderSize: Int32?
        
        /// The xz-plane cell size to use for fields. [Limit: > 0] [Units: wu]
        ///
        /// The voxelization cell size #cs defines the voxel size along both axes of
        /// the ground plane: x and z in Recast. This value is usually derived from the
        /// character radius `r`. A recommended starting value for ``cellSize`` is either `r/2`
        /// or `r/3`. Smaller values of #cs will increase rasterization resolution and
        /// navmesh detail, but total generation time will increase exponentially.  In
        /// outdoor environments, `r/2` is often good enough.  For indoor scenes with
        /// tight spaces you might want the extra precision, so a value of `r/3` or
        /// smaller may give better results.
        ///
        /// The initial instinct is to reduce this value to something very close to zero
        /// to maximize the detail of the generated navmesh. This quickly becomes a case
        /// of diminishing returns, however. Beyond a certain point there's usually not
        /// much perceptable difference in the generated navmesh, but huge increases in
        /// generation time.  This hinders your ability to quickly iterate on level
        /// designs and provides little benefit.  The general recommendation here is to
        /// use as large a value for ``cellSize`` as you can get away with.
        ///
        /// ``cellSize`` and ``cellHeight`` define voxel/grid/cell size.  So their values have significant
        /// side effects on all parameters defined in voxel units.
        ///
        /// The minimum value for this parameter depends on the platform's floating point
        /// accuracy, with the practical minimum usually around 0.05.
        public var cellSize: Float
        
        /// The y-axis cell size to use for fields. [Limit: > 0] [Units: wu]
        /// The y-axis cell size to use for fields. [Limit: > 0] [Units: wu]
        ///
        /// The voxelization ``cellHeight`` is defined separately in order to allow for
        /// greater precision in height tests. A good starting point for ``cellHeight`` is half the
        /// ``cellHeight`` value. Smaller ``cellHeight`` values ensure that the navmesh properly connects
        /// areas that are only separated by a small curb or ditch.  If small holes are generated
        /// in your navmesh around where there are discontinuities in height (for example,
        /// stairs or curbs), you may want to decrease the cell height value to increase
        /// the vertical rasterization precision of Recast.
        ///
        /// ``cellSize`` and ``cellHeight`` define voxel/grid/cell size.  So their values have significant
        /// side effects on all parameters defined in voxel units.
        ///
        /// The minimum value for this parameter depends on the platform's floating point
        /// accuracy, with the practical minimum usually around 0.05.
        public var cellHeight: Float
        
        /// The minimum bounds of the field's AABB. [(x, y, z)] [Units: wu]
        public var bmin: SIMD3<Float>?
        
        /// The maximum bounds of the field's AABB. [(x, y, z)] [Units: wu]
        public var bmax: SIMD3<Float>?
        
        /// The kind of partitioning that you want to use for the heightfield, defaults to ``.watershed``
        public var partitionStyle: PartitionStyle
        
        /// The maximum slope that is considered walkable. [Limits: 0 <= value < 90] [Units: Degrees]
        ///
        /// The parameter ``walkableSlopeAngle`` is to filter out areas of the world where
        /// the ground slope would be too steep for an agent to traverse. This value is
        /// defined as a maximum angle in degrees that the surface normal of a polgyon
        /// can differ from the world's up vector.  This value must be within the range
        /// `[0, 90]`.
        /// The practical upper limit for this parameter is usually around 85 degrees.
        public var walkableSlopeAngle: Float
        
        /// Minimum floor to 'ceiling' height that will still allow the floor area to
        /// be considered walkable. [Limit: >= 3] [Units: vx]
        ///
        /// This value defines the worldspace height `h` of the agent in voxels. Th value
        /// of ``walkableHeight`` should be calculated as `ceil(h / ch)`.  Note this is based
        /// on ``cellHeight`` not ``cellSize`` since it's a height value.
        ///
        /// Permits detection of overhangs in the source geometry that make the geometry
        /// below un-walkable. The value is usually set to the maximum agent height.
        ///
        /// If not set, defaults to 10
        public var walkableHeight: Int32
        
        /// Maximum ledge height that is considered to still be traversable. [Limit: >=0] [Units: vx]
        ///
        /// The `walkableClimb` value defines the maximum height of ledges and steps that
        /// the agent can walk up. Given a designer-defined ``maxClimb`` distance in world
        /// units, the value of #walkableClimb should be calculated as `ceil(maxClimb / ch)`.
        /// Note that this is using #ch not #cs because it's a height-based value.
        ///
        /// Allows the mesh to flow over low lying obstructions such as curbs and
        /// up/down stairways. The value is usually set to how far up/down an agent can step.
        public var walkableClimb: Int32
        
        /// The distance to erode/shrink the walkable area of the heightfield away from
        /// obstructions.  [Limit: >=0] [Units: vx]
        ///
        /// The parameter ``walkableRadius`` defines the worldspace agent radius `r` in voxels.
        /// Most often, this value of #walkableRadius should be calculated as `ceil(r / cs)`.
        /// Note this is based on #cs since the agent radius is always parallel to the ground
        /// plane.
        ///
        /// If the ``walkableRadius`` value is greater than zero, the edges of the navmesh will
        /// be pushed away from all obstacles by this amount.
        ///
        /// A non-zero ``walkableRadius`` allows for much simpler runtime navmesh collision checks.
        /// The game only needs to check that the center point of the agent is contained within
        /// a navmesh polygon.  Without this erosion, runtime navigation checks need to collide
        /// the geometric projection of the agent's logical cylinder onto the navmesh with the
        /// boundary edges of the navmesh polygons.
        ///
        /// In general, this is the closest any part of the final mesh should get to an
        /// obstruction in the source geometry.  It is usually set to the maximum
        /// agent radius.
        ///
        /// If you want to have tight-fitting navmesh, or want to reuse the same navmesh for
        /// multiple agents with differing radii, you can use a ``walkableRadius`` value of zero.
        /// Be advised though that you will need to perform your own collisions with the navmesh
        /// edges, and odd edge cases issues in the mesh generation can potentially occur.  For
        /// these reasons, specifying a radius of zero is allowed but is not recommended.
        public var walkableRadius: Int32

        /// The maximum allowed length for contour edges along the border of the mesh. [Limit: >=0] [Units: vx]
        /// Defaults to 12
        ///
        /// In certain cases, long outer edges may decrease the quality of the resulting
        /// triangulation, creating very long thin triangles. This can sometimes be
        /// remedied by limiting the maximum edge length, causing the problematic long
        /// edges to be broken up into smaller segments.
        ///
        /// The parameter ``maxEdgeLen`` defines the maximum edge length and is defined in
        /// terms of voxels. A good value for #maxEdgeLen is something like
        /// `walkableRadius * 8`. A good way to adjust this value is to first set it really
        /// high and see if your data creates long edges. If it does, decrease ``maxEdgeLen``
        /// until you find the largest value which improves the resulting tesselation.
        ///
        /// Extra vertices will be inserted as needed to keep contour edges below this
        /// length. A value of zero effectively disables this feature.
        public var maxEdgeLen: Int32

        /// The maximum distance a simplified contour's border edges should deviate
        /// the original raw contour. [Limit: >=0] [Units: vx]
        ///
        /// When the rasterized areas are converted back to a vectorized representation,
        /// the ``maxSimplificationError`` describes how loosely the simplification is done.
        /// The simplification process uses the
        /// [Ramer–Douglas-Peucker algorithm](https://en.wikipedia.org/wiki/Ramer–Douglas–Peucker_algorithm),
        /// and this value describes the max deviation in voxels.
        ///
        /// Good values for ``maxSimplificationError`` are in the range `[1.1, 1.5]`.
        /// A value of `1.3` is a good starting point and usually yields good results.
        /// If the value is less than `1.1`, some sawtoothing starts to appear at the
        /// generated edges.  If the value is more than `1.5`, the mesh simplification
        /// starts to cut some corners it shouldn't.
        ///
        /// The effect of this parameter only applies to the xz-plane.
        public var maxSimplificationError: Float
        
        /// The minimum number of cells allowed to form isolated island areas. [Limit: >=0] [Units: vx]
        ///
        /// Watershed partitioning is really prone to noise in the input distance field.
        /// In order to get nicer areas, the areas are merged and small disconnected areas
        /// are removed after the water shed partitioning. The parameter ``minRegionArea``
        /// describes the minimum isolated region size that is still kept. A region is
        /// removed if the number of voxels in the region is less than the square of
        /// ``minRegionArea``
        ///
        /// Any regions that are smaller than this area will be marked as unwalkable.
        /// This is useful in removing useless regions that can sometimes form on
        /// geometry such as table tops, box tops, etc.
        public var minRegionArea: Int32
        
        /// Any regions with a span count smaller than this value will, if possible,
        /// be merged with larger regions. [Limit: >=0] [Units: vx]
        ///
        /// The triangulation process works best with small, localized voxel regions.
        /// The parameter #mergeRegionArea controls the maximum voxel area of a region
        /// that is allowed to be merged with another region.  If you see small patches
        /// missing here and there, you could lower the #minRegionArea value.

        public var mergeRegionArea: Int32
        
        /// The maximum number of vertices allowed for polygons generated during the
        /// contour to polygon conversion process. [Limit: >= 3]
        ///
        /// If the mesh data is to be used to construct a Detour navigation mesh, then the upper limit
        /// is limited to <= #DT_VERTS_PER_POLYGON.
        public var maxVertsPerPoly: Int32

        /// Sets the sampling distance to use when generating the detail mesh.
        /// (For height detail only.) [Limits: 0 or >= 0.9] [Units: wu].
        public var detailSampleDist: Float
        
        /// The maximum distance the detail mesh surface should deviate from heightfield
        /// data. (For height detail only.) [Limit: >=0] [Units: wu].
        public var detailSampleMaxError: Float
        
        /// If set, this will marks non-walkable spans as walkable if their maximum is within ``walkableClimb`` of a walkable neighbor.
        ///
        /// Allows the formation of walkable regions that will flow over low lying
        /// objects such as curbs, and up structures such as stairways.
        ///
        /// Two neighboring spans are walkable if: `(currentSpan.smax - neighborSpan.smax) < walkableClimb`
        ///
        /// Defaults to false
        public var filterLowHangingObstables: Bool
        
        /// If set, marks walkable spans as not walkable if the clearance above the span is less than the specified height.
        ///
        /// For this filter, the clearance above the span is the distance from the span's
        /// maximum to the next higher span's minimum. (Same grid column.)
        ///
        /// Defaults to false
        public var filterWalkableLowHeightSpans: Bool
        
        /// Marks spans that are ledges as not-walkable.
        ///
        /// A ledge is a span with one or more neighbors whose maximum is further away than ``walkableClimb``
        /// from the current span's maximum.
        /// This method removes the impact of the overestimation of conservative voxelization
        /// so the resulting mesh will not have regions hanging in the air over ledges.
        ///
        /// A span is a ledge if: `abs(currentSpan.smax - neighborSpan.smax) > walkableClimb`
        ///
        /// Defaults to false
        public var filterLedgeSpans: Bool
        /// Constructs the configuration object, sets the various properties, additional information on meaning of these parameters
        /// is availale in the property documentation for each one.
        ///
        /// - Parameters:
        ///   - width: The width of the field along the x-axis. [Limit: >= 0] [Units: vx].
        ///     Optional, if not set, it gets computed from the boundaries and cellSize
        ///   - height: The height of the field along the z-axis. [Limit: >= 0] [Units: vx].
        ///     Optional, if not set, it gets computed from the boundaries and cellSize
        ///   - tileSize: The width/height size of tile's on the xz-plane. [Limit: >= 0] [Units: vx]. This field is only used when building multi-tile meshes.
        ///     Defaults to 32.
        ///   - borderSize: This value represents the the closest the walkable area of the heightfield
        ///     should come to the xz-plane AABB of the field. It does not have any
        ///     impact on the borders around internal obstructions.
        ///   - cellSize: The xz-plane cell size to use for fields. [Limit: > 0] [Units: wu]
        ///   - cellHeight: The y-axis cell size to use for fields. [Limit: > 0] [Units: wu]
        ///   - bmin: The minimum bounds of the field's AABB. [(x, y, z)] [Units: wu].  If specified, they are used instead of the computed versions from the actual vertices array.
        ///   - bmax: The maximum bounds of the field's AABB. [(x, y, z)] [Units: wu]. If specified, they are used instead of the computed versions from the actual vertices array.
        ///   - walkableSlopeAngle: The maximum slope that is considered walkable. [Limits: 0 <= value < 90] [Units: Degrees], defaults to 45.  See the propery
        ///     documentation for additioanl information
        ///   - walkableHeight: Minimum floor to 'ceiling' height that will still allow the floor area to
        ///     be considered walkable. [Limit: >= 3] [Units: vx]
        ///   - walkableClimb: Maximum ledge height that is considered to still be traversable. [Limit: >=0] [Units: vx]. Defaults to 4.
        ///   - walkableRadius: he distance to erode/shrink the walkable area of the heightfield away from
        ///     obstructions.  [Limit: >=0] [Units: vx].  Defaults to 2.
        ///   - maxEdgeLen: The maximum allowed length for contour edges along the border of the mesh. [Limit: >=0] [Units: vx].  Defaults to 12.
        ///   - maxSimplificationError: The maximum distance a simplified contour's border edges should deviate
        ///     the original raw contour. [Limit: >=0] [Units: vx].  Defaults to 1.3
        ///   - minRegionArea: The minimum number of cells allowed to form isolated island areas. [Limit: >=0] [Units: vx].
        ///     Defaults to 64 (8 x 8)
        ///   - mergeRegionArea: Any regions with a span count smaller than this value will, if possible, be merged with larger regions.
        ///     [Limit: >=0] [Units: vx].  Defaults to 400 (20 x 20)
        ///   - maxVertsPerPoly: The maximum number of vertices allowed for polygons generated during the
        ///     contour to polygon conversion process. [Limit: >= 3]. Defaults to 6
        ///   - detailSampleDist: Sets the sampling distance to use when generating the detail mesh.
        ///     (For height detail only.) [Limits: 0 or >= 0.9] [Units: wu].   Defaults to 6.0
        ///   - detailSampleMaxError: The maximum distance the detail mesh surface should deviate from heightfield
        ///     data. (For height detail only.) [Limit: >=0] [Units: wu].  Defaults to 1.0
        public init(width: Int32? = nil,
                    height: Int32? = nil,
                    tileSize: Int32 = 32,
                    borderSize: Int32? = nil,
                    cellSize: Float = 0.3,
                    cellHeight: Float = 0.2,
                    bmin: SIMD3<Float>? = nil,
                    bmax: SIMD3<Float>? = nil,
                    partitionStyle: PartitionStyle = .watershed,
                    walkableSlopeAngle: Float = 45,
                    walkableHeight: Int32 = 10,
                    walkableClimb: Int32 = 4,
                    walkableRadius: Int32 = 2,
                    maxEdgeLen: Int32 = 12,
                    maxSimplificationError: Float = 1.3,
                    minRegionArea: Int32 = 64,
                    mergeRegionArea: Int32 = 400,
                    maxVertsPerPoly: Int32 = 6,
                    detailSampleDist: Float = 6,
                    detailSampleMaxError: Float = 1,
                    filterLowHangingObstables: Bool = false,
                    filterLedgeSpans: Bool = false,
                    filterWalkableLowHeightSpans: Bool = false) {
            self.width = width
            self.height = height
            self.tileSize = tileSize
            self.borderSize = borderSize
            self.cellSize = cellSize
            self.cellHeight = cellHeight
            self.bmin = bmin
            self.bmax = bmax
            self.walkableSlopeAngle = walkableSlopeAngle
            self.walkableHeight = walkableHeight
            self.walkableClimb = walkableClimb
            self.walkableRadius = walkableRadius
            self.maxEdgeLen = maxEdgeLen
            self.maxSimplificationError = maxSimplificationError
            self.minRegionArea = minRegionArea
            self.mergeRegionArea = mergeRegionArea
            self.maxVertsPerPoly = maxVertsPerPoly
            self.detailSampleDist = detailSampleDist
            self.detailSampleMaxError = detailSampleMaxError
            self.partitionStyle = partitionStyle
            self.filterLowHangingObstables = filterLowHangingObstables
            self.filterLedgeSpans = filterLedgeSpans
            self.filterWalkableLowHeightSpans = filterWalkableLowHeightSpans
        }
    }
    
    static func flatten (_ d: [SIMD3<Float>]) -> [Float] {
        var ret = Array<Float> (repeating: 0, count: d.count*3)
        var j = 0
        for e in d {
            ret [j] = e.x
            j += 1
            ret [j] = e.y
            j += 1
            ret [j] = e.z
            j += 1
        }
        return ret
    }
    
    /// Creates a new Navmesh from an array of vertices and a configuration
    /// - Parameters:
    ///  - vertices: an array of vertices
    ///  - triangles: triangle index array
    ///  - config: configuration for the creation of this mesh
    ///  - debug: whether you want to run in debug mode or not, debug will enable logging and timers
    public convenience init (vertices: [SIMD3<Float>], triangles: [Int32], config: Config, debug: Bool = true) throws {
        try self.init (vertices: NavMeshBuilder.flatten (vertices), triangles: triangles, config: config, debug: debug)
    }
    
    // Low-level data return by the bulk mesh generation api.
    var llData: UnsafeMutablePointer<BindingBulkResult>
    
    /// Creates a new Navmesh from an array of vertices and a configuration
    /// - Parameters:
    ///  - vertices: an array of floating point values that contain 3 floating point values per vertix (x, y, z)
    ///  - triangles: triangle index array
    ///  - config: configuration for the creation of this mesh
    ///  - debug: whether you want to run in debug mode or not, debug will enable logging and timers
    public init (vertices: [Float], triangles: [Int32], config: Config, debug: Bool = true) throws {
        let bmin, bmax: SIMD3<Float>
        
        if config.bmin == nil || config.bmax == nil {
            var minBounds = SIMD3<Float> ()
            var maxBounds = SIMD3<Float> ()
            
            vertices.withUnsafeBufferPointer { ptr in
                ptr.withMemoryRebound(to: Float.self) { castPtr in
                    withUnsafeMutablePointer(to: &minBounds) { minPtr in
                        minPtr.withMemoryRebound(to: Float.self, capacity: 3) { minPtrCast in
                            withUnsafeMutablePointer(to: &maxBounds) { maxPtr in
                                maxPtr.withMemoryRebound(to: Float.self, capacity: 3) { maxPtrCast in
                                    rcCalcBounds(castPtr.baseAddress, Int32 (vertices.count/3), minPtrCast, maxPtrCast)
                                }
                            }
                        }
                    }
                }
            }
            bmin = minBounds
            bmax = maxBounds
        } else {
            bmin = config.bmin!
            bmax = config.bmax!
        }
        
        var cfg = rcConfig (width: config.width ?? 0,
                            height: config.height ?? 0,
                            tileSize: config.tileSize,
                            borderSize: config.borderSize ?? (config.walkableRadius + 3),
                            cs: config.cellSize,
                            ch: config.cellHeight,
                            bmin: (bmin.x, bmin.y, bmin.z),
                            bmax: (bmax.x, bmax.y, bmax.z),
                            walkableSlopeAngle: config.walkableSlopeAngle,
                            walkableHeight: config.walkableHeight,
                            walkableClimb: config.walkableClimb,
                            walkableRadius: config.walkableRadius,
                            maxEdgeLen: config.maxEdgeLen,
                            maxSimplificationError: config.maxSimplificationError,
                            minRegionArea: config.minRegionArea,
                            mergeRegionArea: config.mergeRegionArea,
                            maxVertsPerPoly: config.maxVertsPerPoly,
                            detailSampleDist: config.detailSampleDist,
                            detailSampleMaxError: config.detailSampleMaxError)
        
        if config.width == nil || config.height == nil {
            withUnsafeMutablePointer(to: &cfg.bmin) { minPtr in
                minPtr.withMemoryRebound(to: Float.self, capacity: 3) { minPtrCast in
                    withUnsafeMutablePointer(to: &cfg.bmax) { maxPtr in
                        maxPtr.withMemoryRebound(to: Float.self, capacity: 3) { maxPtrCast in
                            
                            rcCalcGridSize(minPtrCast, maxPtrCast, cfg.cs, &cfg.width, &cfg.height)
                        }
                    }
                }
            }
        }
        var flags: Int32 = 0
        switch config.partitionStyle {
        case .watershed:
            flags = Int32(PARTITION_WATERSHED)
        case .monotone:
            flags = Int32 (PARTITION_MONOTONE)
        case .layer:
            flags = Int32 (PARTITION_LAYER)
        }
        flags |= config.filterLedgeSpans ? Int32 (FILTER_LEDGE_SPANS) : 0
        flags |= config.filterLowHangingObstables ? Int32 (FILTER_LOW_HANGING_OBSTACLES) : 0
        flags |= config.filterWalkableLowHeightSpans ? Int32 (FILTER_WALKABLE_LOW_HEIGHT_SPANS) : 0
        
        let ret = vertices.withUnsafeBufferPointer { ptr in
            ptr.withMemoryRebound(to: Float.self) { vertPtr in
                triangles.withUnsafeBufferPointer { trianglePtr in
                    bindingRunBulk (&cfg, flags, vertPtr.baseAddress, Int32 (vertices.count/3), trianglePtr.baseAddress, Int32(triangles.count/3))
                }
            }
        }
        guard let ret else {
            throw NavmeshError.memory
        }
        switch ret.pointee.code {
        case BCODE_OK:
            break
        case BCODE_ERR_MEMORY:
            throw NavmeshError.memory
        case BCODE_ERR_RASTERIZE:
            throw NavmeshError.rasterize
        case BCODE_ERR_BUILD_COMPACT_HEIGHTFIELD:
            throw NavmeshError.buildCompactHeightfield
        case BCODE_ERR_BUILD_LAYER_REGIONS:
            throw NavmeshError.buildLayerRegions
        case BCODE_ERR_BUILD_REGIONS_MONOTONE:
            throw NavmeshError.buildRegionsMonotone
        case BCODE_ERR_BUILD_DISTANCE_FIELD:
            throw NavmeshError.buildDistanceField
        case BCODE_ERR_BUILD_REGIONS:
            throw NavmeshError.buildRegions
        case BCODE_ERR_ALLOC_CONTOUR:
            throw NavmeshError.allocCountour
        case BCODE_ERR_BUILD_CONTOUR:
            throw NavmeshError.buildContour
        case BCODE_ERR_ALLOC_POLYMESH:
            throw NavmeshError.allocPolyMesh
        case BCODE_ERR_BUILD_POLY_MESH:
            throw NavmeshError.buildPolyMesh
        case BCODE_ERR_ALLOC_DETAIL_POLY_MESH:
            throw NavmeshError.allocDetailPolyMesh
        case BCODE_ERR_BUILD_DETAIL_POLY_MESH:
            throw NavmeshError.buildDetailPolyMesh
        default:
            throw NavmeshError.unknown
        }
        
        llData = ret
    }
    
    /// Returns a representation suitable for navigation, but also to be stored on disk
    /// or transferred
    public func makeNavigationBlob (agentHeight: Float, agentRadius: Float, agentMaxClimb: Float) throws -> Data {
        var ptr: UnsafeMutableRawPointer?
        var size: Int32 = 0
        let r = bindingGenerateDetour(llData, agentHeight, agentRadius, agentMaxClimb, &ptr, &size)
        
        switch r {
        case BD_OK:
            break;
        case BD_ERR_VERTICES:
            throw NavBuilderError.vertices
        case BD_ERR_ALLOC_NAVMESH:
            throw NavBuilderError.alloc
        case BD_ERR_BUILD_NAVMESH:
            throw NavBuilderError.build
        default:
            throw NavmeshError.unknown
        }
        if ptr == nil {
            throw NavmeshError.unknown
        }
        return Data (bytesNoCopy: ptr!, count: Int(size), deallocator: .free)
    }

    @available(macOS 13.3.0, *)
    public func makeNavMesh (agentHeight: Float, agentRadius: Float, agentMaxClimb: Float) throws -> NavMesh {
        var ptr: UnsafeMutableRawPointer?
        var size: Int32 = 0
        let r = bindingGenerateDetour(llData, agentHeight, agentRadius, agentMaxClimb, &ptr, &size)
        
        switch r {
        case BD_OK:
            break;
        case BD_ERR_VERTICES:
            throw NavBuilderError.vertices
        case BD_ERR_ALLOC_NAVMESH:
            throw NavBuilderError.alloc
        case BD_ERR_BUILD_NAVMESH:
            throw NavBuilderError.build
        default:
            throw NavmeshError.unknown
        }
        if ptr == nil {
            throw NavmeshError.unknown
        }
        return try NavMesh (ptr!, size: size)
    }

    deinit {
        bindingRelease(llData)
    }

    /// Errors raised when we attempt to turn the navigation data into navigational data
    public enum NavBuilderError: Error {
        /// The number of vertices used for this configuration exceeds the limit that is supported
        /// by Detour.
        case vertices
        /// There was a problem allocating the data structures necessary for this mesh
        case alloc
        /// There was an error creating the navigational mesh
        case build
    }
    /// Errors thrown by the creation of the mesh object
    public enum NavmeshError: Error {
        /// There was no memory available to allocate
        case memory
        /// It was not possible to create the heightfield
        case cannotCreateHeightField
        /// Error during triangle rasterization
        case rasterize
        /// Error building the compact height field
        case buildCompactHeightfield
        /// Error building the layer regions (when using ``PartitionType.layer``
        case buildLayerRegions
        /// Error building the monotone regions (when using ``PartitionLayer.monotone``
        case buildRegionsMonotone
        /// Error building the distance field (when using ``PartitionLayer.watershed``)
        case buildDistanceField
        /// Error building the regions (when using ``PartitionLayer.watershed``)
        case buildRegions
        /// Not enough memory to allocate the contour
        case allocCountour
        /// Error while building the contour
        case buildContour
        /// Internal library error, an unhandled case, should never happen
        case unknown
        /// Not enough memory to allocate the poly mesh
        case allocPolyMesh
        /// Error buildling the poly mesh
        case buildPolyMesh
        /// Not enough memory to allocate the detailed poly mesh
        case allocDetailPolyMesh
        /// Error buildling the detailed poly mesh
        case buildDetailPolyMesh
    }

}
