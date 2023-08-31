//
//  File.swift
//  
//
//  Created by Miguel de Icaza on 8/29/23.
//

import Foundation

#if canImport(RealityKit)
import RealityKit

/// An agent component can be attached to a RealityKit entity and
/// can control its behavior given the goals of the ``CrowdAgent`` it
/// was initialized with.
///
/// You must register this component before use, by calling
/// `AgentComponent.registerComponent()`
///
/// ```
/// // This creates an new agent on the `from` crowd and attaches an
/// // AgentComponent to the provided entity.
/// func createAtgent (from crowd: Crowd, on entity: Entity, at position: SIMD3<Float>) -> Agent? {
///     if let agent = crowd.addAgent (position) {
///         entity.components.set (AgentComponent (agent))
///         return agent
///     }
///     return nil
/// }
///
/// // Create an agent at (0, 0, 0) and request that it navigates to
/// // (1, 1, 1)
/// if let agent = createAgent (crowd, myEntity, [0, 0, 0]) {
///     agent.requestMove (target: [1, 1, 1])
/// }
/// ```
public struct AgentComponent: Component {
    /// The ``CrowdAgent`` which can be accessed to change the goals of the agent at runtime.
    public let agent: CrowdAgent
    
    /// The ``CrowdAgent`` that can be used to configure the behavior of the agent.
    public init (_ agent: CrowdAgent) {
        self.agent = agent
    }
}

#endif
