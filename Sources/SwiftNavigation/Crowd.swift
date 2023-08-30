//
//  Crowd.swift
//  NavigationSample
//
//  Created by Miguel de Icaza on 8/24/23.
//

import Foundation
import CRecast

/// Crowds implement local steering and dynamic avoidance features.
///
/// The crowd is the big beast of the navigation features. It not only handles a
/// lot of the path management for you, but also local steering and dynamic
/// avoidance between members of the crowd. I.e. It can keep your agents from
/// running into each other.
///
/// The ``NavMeshQuery`` and ``PathCorridor`` classes provide perfectly good, easy
/// to use path planning features. But in the end they only give you points that
/// your navigation client should be moving toward. When it comes to deciding things
/// like agent velocity and steering to avoid other agents, that is up to you to
/// implement. Unless, of course, you decide to use ``Crowd``.
///
/// To use, you add an agent to the crowd, providing various configuration
/// settings such as maximum speed and acceleration. You also provide a local
/// target to more toward. The crowd manager then provides, with every update, the
/// new agent position and velocity for the frame. The movement will be
/// constrained to the navigation mesh, and steering will be applied to ensure
/// agents managed by the crowd do not collide with each other.
///
/// This is very powerful feature set. But it comes with limitations.
///
/// The biggest limitation is that you must give control of the agent's position
/// completely over to the crowd manager. You can update things like maximum speed
/// and acceleration. But in order for the crowd manager to do its thing, it can't
/// allow you to constantly be giving it overrides to position and velocity. So
/// you give up direct control of the agent's movement. It belongs to the crowd.
///
/// The second biggest limitation revolves around the fact that the crowd manager
/// deals with local planning. So the agent's target should never be more than
/// 256 polygons aways from its current position. If it is, you risk
/// your agent failing to reach its target. So you may still need to do long
/// distance planning and provide the crowd manager with intermediate targets.
///
/// Other significant limitations:
///
/// - All agents using the crowd manager will use the same ``QueryFilter``.
/// - Crowd management is relatively expensive. The maximum agents under crowd
///   management at any one time is between 20 and 30.  A good place to start
///   is a maximum of 25 agents for 0.5ms per frame.
///
public class Crowd {
    /// Errors raised by the Crowd subsystem
    public enum CrowdError: Error {
        /// Could not allocate a new dtCrowd object
        case alloc
        /// Initialization error in the crowd runtime
        case initialization
        /// Invalid obstacle reference
        case invalidObstacleId
    }
    
    var crowd: dtCrowd

    init (maxAgents: Int32, agentRadius: Float, nav: NavMesh) throws {
        guard let crowd = dtAllocCrowd() else {
            throw CrowdError.alloc
        }
        guard crowd.`init`(maxAgents, agentRadius, nav.navMesh) else {
            throw CrowdError.initialization
        }
        self.crowd = crowd
    }
    
    /// Sets the shared avoidance configuration for the specified index.
    ///
    /// The index that you set can be configured in the ``CrowdAgent`` by calling the
    /// ``CrowdAgent/set(obstacleAvoidanceType:)`` method on it.
    ///
    /// - Parameters:
    ///  - idx: the index to set (between 0 and 8, unless compiled with a larger value)
    ///  - config: the configuration parametrs
    public func setObstableAvoidance (idx: Int, config: ObstacleAvoidanceConfig) {
        var p = dtObstacleAvoidanceParams(velBias: config.velocitySelectionBias,
                                          weightDesVel: config.desiredVelocityWeight,
                                          weightCurVel: config.currentVelocityWeight,
                                          weightSide: config.preferredSideWeight,
                                          weightToi: config.collisionTimeWeight,
                                          horizTime: config.timeHorizon,
                                          gridSize: config.samplingGridSize,
                                          adaptiveDivs: config.adaptiveDivs,
                                          adaptiveRings: config.adaptiveRings,
                                          adaptiveDepth: config.adaptiveDepth)
        
        crowd.setObstacleAvoidanceParams(Int32(idx), &p)
    }
    
    /// Returns the obstacle avoidance configuration for a specific slot
    public func getObstacleAvoidance (idx: Int) throws -> ObstacleAvoidanceConfig {
        guard let r = dtCrowdGetObstacleAvoidanceParams(crowd, Int32(idx))?.pointee else {
            throw CrowdError.invalidObstacleId
        }
        return ObstacleAvoidanceConfig(velocitySelectionBias: r.velBias, desiredVelocityWeight: r.weightDesVel, currentVelocityWeight: r.weightCurVel, preferredSideWeight: r.weightSide, collisionTimeWeight: r.weightToi, timeHorizon: r.horizTime, samplingGridSize: r.gridSize, adaptiveDivs: r.adaptiveDivs, adaptiveRings: r.adaptiveRings, adaptiveDepth: r.adaptiveDepth)
    }
    
    /// Adds a new agent to the crowd
    /// - Parameters:
    ///   - position: Requested position for the agent.
    ///   - radius: agent radius.
    ///   - height: agent height.
    ///   - maxAcceleration: Maximum allowed acceleration.
    ///   - maxSpeed: Maximum allowed speed.
    ///   - collisionQueryRange: Defines how close a collision element must be before it is considered for steering behaviors.
    ///     If this value is not provided, then it is computed as `radius * 12`
    ///   - pathOptimizationRange: The path visibility optimization range.
    ///     If this value is not provided, then it is computed as `radius * 30`
    ///   - updateFlags: Flags that impact steering behavior
    ///   - obstableAvoidanceType: The index of the avoidance configuration to use for the agent (set with ``setObstableAvoidance(idx:config:)``
    ///   - queryFilterIndex: The index of the query filter used by this agent.
    ///   - separationWeight: How aggresive the agent manager should be at avoiding collisions with this agent.
    /// - Returns: An agent on success, or nil if it was not possible to add the agent
    public func addAgent (_ position: SIMD3<Float>,
                          radius: Float = 0.6,
                          height: Float = 2.0,
                          maxAcceleration: Float = 8,
                          maxSpeed: Float = 3.5,
                          collisionQueryRange: Float? = nil,
                          pathOptimizationRange: Float? = nil,
                          updateFlags: UpdateFlags = UpdateFlags(rawValue: 0),
                          obstableAvoidanceType: UInt8 = 3,
                          queryFilterIndex: UInt8 = 0,
                          separationWeight: Float = 2) -> CrowdAgent? {
        var params = dtCrowdAgentParams (
            radius: radius,
            height: height,
            maxAcceleration: maxAcceleration,
            maxSpeed: maxSpeed,
            collisionQueryRange: collisionQueryRange ?? radius * 12,
            pathOptimizationRange: pathOptimizationRange ?? radius * 30,
            separationWeight: separationWeight,
            updateFlags: UInt8 (updateFlags.rawValue),
            obstacleAvoidanceType: obstableAvoidanceType,
            queryFilterType: queryFilterIndex,
            userData: nil)
        var pos: [Float] = [position.x, position.y, position.z]
        let idx = crowd.addAgent(&pos, &params)
        guard idx != -1 else {
            return nil
        }
        return CrowdAgent (crowd: self, idx: idx)
    }
    
    /// Adds a new agent to the crowd 
    /// - Parameters:
    ///   - position: Requested position for the agent.
    /// - Returns: An agent on success, or nil if it was not possible to add the agent
    public func addAgent (_ position: SIMD3<Float>, params: CrowdAgent.Params) -> CrowdAgent? {
        var params2 = params.todtCrowdAgentParams ()
        var pos: [Float] = [position.x, position.y, position.z]

        let idx = crowd.addAgent(&pos, &params2)
        guard idx != -1 else {
            return nil
        }
        return CrowdAgent (crowd: self, idx: idx)
    }
    
    /// Removes an agent from the crowd
    public func remove (agent: CrowdAgent) {
        crowd.removeAgent(agent.idx)
        agent.idx = -1
    }
    
    /// Update the simulation.
    /// - Parameter dt: the time in seconds, to update the simulation
    public func update (time: Float) {
        crowd.update(time, nil)
    }
    
    deinit {
        dtFreeCrowd (crowd)
    }
    
    /// Obstacle configuration information, you can create up to eight of these and set them
    /// on the ``Crowd`` instance by calling ``setObstableAvoidance(idx:config:)``.
    public struct ObstacleAvoidanceConfig {
        public var velocitySelectionBias: Float
        public var desiredVelocityWeight: Float
        public var currentVelocityWeight: Float
        public var preferredSideWeight: Float
        public var collisionTimeWeight: Float
        public var timeHorizon: Float
        public var samplingGridSize: UInt8
        public var adaptiveDivs: UInt8
        public var adaptiveRings: UInt8
        public var adaptiveDepth: UInt8
    }
    
    /// The maximum number of agents that can be managed by the object.
    public var maxAgentCount: Int {
        Int (crowd.getAgentCount())
    }
}
