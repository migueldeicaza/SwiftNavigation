//
//  Agent.swift
//  NavigationSample
//
//  Created by Miguel de Icaza on 8/24/23.
//

import Foundation
import CRecast

@available(macOS 13.3.0, *)
public class CrowdAgent {
    var crowd: Crowd
    var idx: Int32
    
    init (crowd: Crowd, idx: Int32) {
        self.crowd = crowd
        self.idx = idx
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
            let r = dtCrowdGetAgent(crowd.crowd, idx)!
            var p = newValue.todtCrowdAgentParams()
            crowd.crowd.updateAgentParameters(idx, &p)
        }
    }
    
    /// Sets the agent maximum acceleration, a convenience over setting all the parameters
    public func set (maxAcceleration: Float) {
        if maxAcceleration >= 0 {
            let c = crowd.crowd
            let r = dtCrowdGetAgent(c, idx)!
            var copy = r.params
            copy.maxAcceleration = maxAcceleration
            c.updateAgentParameters(idx, &copy)
        }
    }

    /// Sets the agent maximum speed, a convenience over setting all the parameters
    public func set (maxSpeed: Float) {
        if maxSpeed >= 0 {
            let c = crowd.crowd
            let r = dtCrowdGetAgent(c, idx)!
            var copy = r.params
            copy.maxSpeed = maxSpeed
            c.updateAgentParameters(idx, &copy)
        }
    }
    
    /// Sets the agent radius, a convenience over setting all the parameters
    public func set (radius: Float) {
        if radius >= 0 {
            let c = crowd.crowd
            let r = dtCrowdGetAgent(c, idx)!
            var copy = r.params
            copy.radius = radius
            c.updateAgentParameters(idx, &copy)
        }
    }

    /// Sets the agent height, a convenience over setting all the parameters
    public func set (height: Float) {
        if height >= 0 {
            let c = crowd.crowd
            let r = dtCrowdGetAgent(c, idx)!
            var copy = r.params
            copy.radius = height
            c.updateAgentParameters(idx, &copy)
        }
    }
    
    /// Sets the query filter type, a convenience over setting all the parameters
    /// - Parameter queryFilterType: the index of the query filter to use
    public func set (queryFilterType: UInt8) {
        guard queryFilterType < DT_CROWD_MAX_QUERY_FILTER_TYPE else { return }
        let c = crowd.crowd
        let r = dtCrowdGetAgent(c, idx)!
        var copy = r.params
        copy.queryFilterType = queryFilterType
        c.updateAgentParameters(idx, &copy)
    }

    /// Sets the query filter type, a convenience over setting all the parameters
    public func set (obstacleAvoidanceType: UInt8) {
        guard obstacleAvoidanceType < DT_CROWD_MAX_OBSTAVOIDANCE_PARAMS else { return }
        let c = crowd.crowd
        let r = dtCrowdGetAgent(c, idx)!
        var copy = r.params
        copy.obstacleAvoidanceType = obstacleAvoidanceType
        c.updateAgentParameters(idx, &copy)
    }

    /// Sets the navigation quality to one of the presets, these control
    /// the path finding, steering and velocity planning flags from ``UpdateFlags``
    public func set (navigationQuality: NavigationQuality) {
        let c = crowd.crowd
        let r = dtCrowdGetAgent(c, idx)!
        var copy = r.params
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
        copy.updateFlags = UInt8 (flags)
        c.updateAgentParameters(idx, &copy)
    }

    /// Sets the navigation quality to one of the presets, these control
    /// the path finding, steering and velocity planning flags from ``UpdateFlags``
    public func set (navigationPushiness: NavigationPushiness) {
        let c = crowd.crowd
        let r = dtCrowdGetAgent(c, idx)!
        var copy = r.params
        switch navigationPushiness {
        case .low:
            copy.separationWeight = 4
            copy.collisionQueryRange = copy.radius * 16
        case .medium:
            copy.separationWeight = 2
            copy.collisionQueryRange = copy.radius * 8
        case .high:
            copy.separationWeight = 0.5
            copy.collisionQueryRange = copy.radius
        case .none:
            copy.separationWeight = 0
            copy.collisionQueryRange = copy.radius
        }
        c.updateAgentParameters(idx, &copy)
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
        var copy: [Float] = [velocity.x, velocity.y, velocity.z]
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
        /// ``CrowdAgent.UpdateFlags.optimizeVisibility``
        /// and ``CrowdAgent.UpdateFlags.anticipateTurns``
        case low
        /// This is a preset that sets the ``params`` updateFlags
        /// to ``CrowdAgent.UpdateFlags.optimizeVisibility``,  ``CrowdAgent.UpdateFlags.anticipateTurns``,
        /// ``CrowdAgent.UpdateFlags.separation`` and ``CrowdAgent.UpdateFlags.optimizeTopology``

        case medium
        
        /// This is a preset that sets the ``params`` updateFlags to ``CrowdAgent.UpdateFlags.optimizeVisibility``,
        /// ``CrowdAgent.UpdateFlags.anticipateTurns``, ``CrowdAgent.UpdateFlags.separation``,
        /// ``CrowdAgent.UpdateFlags.optimizeTopology`` and ``CrowdAgent.UpdateFlags.obstacleAvoidance``
        case high
    }

    /// Convenience enumerations for controlling the `separationWeight` and `collisionQueryRange`
    ///  parameters of the agent, and they control how strongly an agent will push colliding neighbours around
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

