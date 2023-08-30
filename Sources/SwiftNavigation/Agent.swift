//
//  Agent.swift
//  NavigationSample
//
//  Created by Miguel de Icaza on 8/24/23.
//

import Foundation
import CRecast

/// An agent managed by ``Crowd``
///
/// Agents are created by calling one of ``Crowd``'s `addAgent` methods.
///
/// After the agent has been created, the configuration of the agent can be updated by changing the
/// ``param`` property that contains a structure with all the configuration parameters.  As a
/// convenience, individual properties are provided for quick changes.
///
/// The convenience ``set(navigationQuality:)`` and ``set(navigationPushiness:)`` can help
/// you use various presets that affect the navigation quality and pushiness in one go.
///
/// You request the agent to move to a specific location using ``requestMove(target:)`` or ``requestMove(velocity:)``
/// and you can cancel this request by calling ``resetMove()``.
///
/// After a time update, the agent's ``position`` and ``velocity`` are updated to reflect the
/// state of the agent.
public class CrowdAgent: CustomDebugStringConvertible {
    var crowd: Crowd
    var idx: Int32
    
    init (crowd: Crowd, idx: Int32) {
        self.crowd = crowd
        self.idx = idx
    }
    
    public var debugDescription: String {
        return "Agent[\(idx)]"
    }
    
    /// This property access the agent parameters, setitng it will update the running parameters.
    public var params: CrowdAgent.Params {
        get {
            // This can never fail
            let r = dtCrowdGetAgent(crowd.crowd, idx)!
            let p = r.params
            return CrowdAgent.Params(radius: p.radius, height: p.height, maxAcceleration: p.maxAcceleration, maxSpeed: p.maxSpeed, collisionQueryRange: p.collisionQueryRange, pathOptimizationRange: p.pathOptimizationRange, separationWeight: p.separationWeight, updateFlags: UpdateFlags (rawValue: p.updateFlags), obstacleAvoidanceType: p.obstacleAvoidanceType, queryFilterType: p.queryFilterType, userData: p.userData)
        }
        set {
            var p = newValue.todtCrowdAgentParams()
            crowd.crowd.updateAgentParameters(idx, &p)
        }
    }
    
    func update (_ body: (inout dtCrowdAgentParams) -> Void) {
        var copy = dtCrowdGetAgent (crowd.crowd, idx).params
        body (&copy)
        crowd.crowd.updateAgentParameters(idx, &copy)
    }
    
    func getParams () -> dtCrowdAgentParams {
        dtCrowdGetAgent (crowd.crowd, idx).params
    }
    
    /// Agent radius. [Limit: >= 0]
    ///
    /// Convenience to change a single parameter.
    public var radius: Float {
        get { getParams().radius }
        set { update { p in p.radius = newValue } }
    }
    
    /// Agent height. [Limit: >= 0]
    ///
    /// Convenience to change a single parameter.
    public var height: Float {
        get { getParams().height }
        set { update { p in p.height = newValue } }
    }

    /// Maximum allowed acceleration. [Limit: >= 0]
    ///
    /// Convenience to change a single parameter.
    public var maxAcceleration: Float {
        get { getParams().maxAcceleration }
        set { update { p in p.maxAcceleration = newValue } }
    }
        
    /// Maximum allowed speed. [Limit: >= 0]
    ///
    /// Convenience to change a single parameter.
    public var maxSpeed: Float {
        get { getParams ().maxSpeed }
        set { 
            if newValue >= 0 {
                update { p in p.maxSpeed = newValue }
            }
        }
    }
    
    /// The query filter type, a convenience over setting all the parameters
    ///
    /// Convenience to change a single parameter.
    public var queryFilterType: UInt8 {
        get { getParams ().queryFilterType }
        set { 
            guard newValue < DT_CROWD_MAX_QUERY_FILTER_TYPE else { return }
            update { p in p.queryFilterType = newValue }
        }
    }

    /// The query filter type.
    ///
    /// Convenience to change a single parameter.
    public var obstacleAvoidanceType: Int {
        get { Int (getParams ().obstacleAvoidanceType) }
        set { 
            guard newValue < DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS || newValue >= 0 else { return }
            update { p in p.obstacleAvoidanceType = UInt8 (obstacleAvoidanceType) }
        }
    }

    /// Defines how close a collision element must be before it is considered for steering behaviors. [Limits: > 0]
    ///
    /// Convenience to change a single parameter.
    public var collisionQueryRange: Float {
        get { getParams().collisionQueryRange }
        set { update { p in p.collisionQueryRange = newValue } }
    }
    
    /// The path visibility optimization range. [Limit: > 0]
    ///
    /// Convenience to change a single parameter.
    public var pathOptimizationRange: Float {
        get { getParams().pathOptimizationRange }
        set { update { p in p.pathOptimizationRange = newValue }}
    }
    
    /// How aggresive the agent manager should be at avoiding collisions with this agent. [Limit: >= 0]
    public var separationWeight: Float {
        get { getParams().separationWeight }
        set { update { p in p.separationWeight = newValue }}
    }
    
    /// Flags that impact steering behavior
    public var updateFlags: UpdateFlags {
        get { UpdateFlags (rawValue: getParams().updateFlags) }
        set { update { p in p.updateFlags = newValue.rawValue }}
    }
    
    /// Sets the navigation quality to one of the presets, these control
    /// the path finding, steering and velocity planning flags from ``UpdateFlags``
    public func set (navigationQuality: NavigationQuality) {
        var flags: UInt32 = 0
        switch navigationQuality {
        case .low:
            flags = DT_CROWD_OPTIMIZE_VIS.rawValue | DT_CROWD_ANTICIPATE_TURNS.rawValue
        case .medium:
            flags = DT_CROWD_OPTIMIZE_TOPO.rawValue
            | DT_CROWD_OPTIMIZE_VIS.rawValue
            | DT_CROWD_ANTICIPATE_TURNS.rawValue
            | DT_CROWD_SEPARATION.rawValue

        case .high:
            flags = DT_CROWD_OPTIMIZE_TOPO.rawValue
            | DT_CROWD_OPTIMIZE_VIS.rawValue
            | DT_CROWD_ANTICIPATE_TURNS.rawValue
            | DT_CROWD_SEPARATION.rawValue
            | DT_CROWD_OBSTACLE_AVOIDANCE.rawValue
        }
        update { p in p.updateFlags = UInt8 (flags) }
    }

    /// Sets the navigation pushiness to one of the presets.
    /// The higher the setting, the stronger the agent pushes its colliding neighbours around.
    public func set (navigationPushiness: NavigationPushiness) {
        update { p in
            switch navigationPushiness {
            case .low:
                p.separationWeight = 4
                p.collisionQueryRange = p.radius * 16
            case .medium:
                p.separationWeight = 2
                p.collisionQueryRange = p.radius * 8
            case .high:
                p.separationWeight = 0.5
                p.collisionQueryRange = p.radius
            case .none:
                p.separationWeight = 0
                p.collisionQueryRange = p.radius
            }
        }
    }
    
    @discardableResult
    /// Submits a new move request for the specified agent.
    /// - Parameter target: location for this agent to target
    /// - Returns: true for a valid request, false for an invalid one
    public func requestMove (target: PointInPoly) -> Bool {
        crowd.crowd.requestMoveTarget(idx, target.polyRef, target.point)
    }

    @discardableResult
    /// Submits a new move request velociy for the specified agent.
    /// - Parameter velocitt: the desired velocity for the agent
    /// - Returns: true for a valid request, false for an invalid one
    public func requestMove (velocity: SIMD3<Float>) -> Bool {
        let copy: [Float] = [velocity.x, velocity.y, velocity.z]
        return crowd.crowd.requestMoveVelocity(idx, copy)
    }
    
    @discardableResult
    /// Resets any request for the specified agent.
    /// - Returns: true for a valid request, false for an invalid one
    public func resetMove () -> Bool {
        return crowd.crowd.resetMoveTarget(idx)
    }
    
    /// The agent's position
    public var position: SIMD3<Float> {
        let pos = crowd.crowd.getAgent(idx)!.npos
        return SIMD3<Float> (pos.0, pos.1, pos.2)
    }
    
    /// The actual velocity of the agent. The change from nvel -> vel is constrained by max acceleration. 
    public var velocity: SIMD3<Float> {
        let nvel = crowd.crowd.getAgent(idx)!.nvel
        return SIMD3<Float> (nvel.0, nvel.1, nvel.2)
    }
    
    /// These are presets that affect the computational cost of the navigation and affect the agent ``UpdateFlags``
    public enum NavigationQuality {
        /// This is a preset that sets the ``params`` updateFlags to
        /// ``CrowdAgent/UpdateFlags/optimizeVisibility``
        /// and ``CrowdAgent/UpdateFlags/anticipateTurns``
        case low
        /// This is a preset that sets the ``params`` updateFlags
        /// to ``CrowdAgent/UpdateFlags/optimizeVisibility``,  ``CrowdAgent/UpdateFlags/anticipateTurns``,
        /// ``CrowdAgent/UpdateFlags/separation`` and ``CrowdAgent/UpdateFlags/optimizeTopology``

        case medium
        
        /// This is a preset that sets the ``params`` updateFlags to ``CrowdAgent/UpdateFlags/optimizeVisibility``,
        /// ``CrowdAgent/UpdateFlags/anticipateTurns``, ``CrowdAgent/UpdateFlags/separation``,
        /// ``CrowdAgent/UpdateFlags/optimizeTopology`` and ``CrowdAgent/UpdateFlags/obstacleAvoidance``
        case high
    }

    /// Convenience enumerations for controlling the `separationWeight` and `collisionQueryRange`
    /// parameters of the agent, and they control how strongly an agent will push colliding neighbours around
    public enum NavigationPushiness {
        /// separation weight of 4.0, collisionQueryRange is radius x 16
        case low
        /// separation weight of 2.0, collisionQueryRange is radius x 8
        case medium
        /// separation weight of 0.5, collisionQueryRange is radius
        case high
        /// separation weight of 0, collisionQueryRange is radius
        case none
    }
    
    /// The Crowd agent parameters, when you want to alter those in bulk.
    public struct Params {
        public init(radius: Float, height: Float, maxAcceleration: Float, maxSpeed: Float, collisionQueryRange: Float, pathOptimizationRange: Float, separationWeight: Float, updateFlags: UpdateFlags, obstacleAvoidanceType: UInt8, queryFilterType: UInt8, userData: UnsafeMutableRawPointer!){
            self.radius = radius
            self.height = height
            self.maxAcceleration = maxAcceleration
            self.maxSpeed = maxSpeed
            self.collisionQueryRange = collisionQueryRange
            self.pathOptimizationRange = pathOptimizationRange
            self.separationWeight = separationWeight
            self.updateFlags = updateFlags
            self.obstacleAvoidanceType = obstacleAvoidanceType
            self.queryFilterType = queryFilterType
            self.userData = userData
        }
        
        func todtCrowdAgentParams () -> dtCrowdAgentParams {
            dtCrowdAgentParams(radius: radius, height: height, maxAcceleration: maxAcceleration, maxSpeed: maxSpeed, collisionQueryRange: collisionQueryRange, pathOptimizationRange: pathOptimizationRange, separationWeight: separationWeight, updateFlags: UInt8 (updateFlags.rawValue), obstacleAvoidanceType: obstacleAvoidanceType, queryFilterType: queryFilterType, userData: userData)
        }
        
        /// Agent radius. [Limit: >= 0]
        public var radius: Float

        /// Agent height. [Limit: > 0]
        public var height: Float

        /// Maximum allowed acceleration. [Limit: >= 0]
        public var maxAcceleration: Float

        /// Maximum allowed speed. [Limit: >= 0]
        public var maxSpeed: Float
        
        /// Defines how close a collision element must be before it is considered for steering behaviors. [Limits: > 0]
        public var collisionQueryRange: Float
        
        /// The path visibility optimization range. [Limit: > 0]
        public var pathOptimizationRange: Float
        
        /// How aggresive the agent manager should be at avoiding collisions with this agent. [Limit: >= 0]
        public var separationWeight: Float
        
        /// Flags that impact steering behavior
        public var updateFlags: UpdateFlags

        /// The index of the avoidance configuration to use for the agent.
        /// [Limits: 0 <= value <= #DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS]
        public var obstacleAvoidanceType: UInt8
        
        /// The index of the query filter used by this agent.
        public var queryFilterType: UInt8

        /// User defined data attached to the agent.
        public var userData: UnsafeMutableRawPointer!
    }

    /// Crowd agent update flags
    ///
    /// Path finding is affected by ``optimizeTopology`` and ``optimizeVisibility``
    /// Steering is affected by ``anticipateTurns`` and ``separation``
    /// Velocity planning is affected by ``obstacleAvoidance``
    public struct UpdateFlags: OptionSet {
        public let rawValue: UInt8
        public init (rawValue: UInt8) {
            self.rawValue = rawValue
        }
        init (value: CRecast.UpdateFlags) {
            self.rawValue = UInt8 (value.rawValue)
        }
        public static let anticipateTurns = UpdateFlags (value: DT_CROWD_ANTICIPATE_TURNS)
        public static let obstacleAvoidance = UpdateFlags (value: DT_CROWD_OBSTACLE_AVOIDANCE)
        public static let separation = UpdateFlags (value: DT_CROWD_SEPARATION)
        // #dtPathCorridor::optimizePathVisibility() to optimize the agent path.
        public static let optimizeVisibility = UpdateFlags (value: DT_CROWD_OPTIMIZE_VIS)
        // Use dtPathCorridor::optimizePathTopology() to optimize the agent path.
        public static let optimizeTopology = UpdateFlags (value: DT_CROWD_OPTIMIZE_TOPO)

    }
}

