//
//  Agent.swift
//  NavigationSample
//
//  Created by Miguel de Icaza on 8/24/23.
//

import Foundation
import CRecast

@available(macOS 13.3.0, *)
public class Agent {
    weak var crowd: Crowd?
    var idx: Int32
    
    init (crowd: Crowd, idx: Int32) {
        self.crowd = crowd
        self.idx = idx
    }
}
