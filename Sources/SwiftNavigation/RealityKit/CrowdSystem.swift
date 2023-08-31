//
//  File.swift
//
//
//  Created by Miguel de Icaza on 8/31/23.
//

import Foundation

#if canImport(RealityKit)
import RealityKit

/// The crowd system is responsible for updating the position of all
/// entities that have an attached ``AgentComponent``.
///
/// You must call ``CrowdSystem.registerSystem`` before this will work.
///
/// To create a Crowd, you must create a ``Crowd`` object out of your ``NavMesh`` using ``NavMesh/makeCrowd(maxAgents:agentRadius:)``, and then create an agent with
/// your desired configuration parameters and wrap this on an ``AgentComponent``:
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
///
public class CrowdSystem: System {
    static let query = EntityQuery(where: .has(AgentComponent.self))
    
    public required init(scene: Scene) {
    }
    
    public func update(context: SceneUpdateContext) {
        var crowds: [Crowd] = []
        var crowd: Crowd? = nil
        context.scene.performQuery(Self.query).forEach { entity in
            
            guard let agentComponent = entity.components [AgentComponent.self] else {
                return
            }
            let agent = agentComponent.agent
            let agentCrowd = agent.crowd
            
            // Ensure all the crowd systems have been invoked, there might be more
            // than one crowd system active
            if crowd == nil {
                crowd = agentCrowd
                crowds = [agentCrowd]
                agentCrowd.update(time: Float (context.deltaTime))
            } else if crowd === agent.crowd {
                // common path, single crowd.
                // update was already called on this crowd
            } else {
                // We have more than one crowd active
                if crowds.contains (where: { $0 === agentCrowd }) {
                    // No need to do anything, the crowd update has already been called
                } else {
                    // Ok, a new crowd showed up, make sure we call the update function
                    crowds.append(agentCrowd)
                    agentCrowd.update (time: Float (context.deltaTime))
                }
            }
            entity.position = agent.position
        }
    }
}
#endif

