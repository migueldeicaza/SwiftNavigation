//
//  NavQueryFilter.swift
//  NavigationSample
//
//  Created by Miguel de Icaza on 8/23/23.
//

import Foundation
import CRecast

/// The filter is used to describe the flags that are included when doing polygon evaluation
/// you set the `includeFlags` and `excludeFlags` to match those attribtues in the
/// region areas to include or exclude from searches.
///
/// At construction: All area costs default to 1.0.  All flags are included
/// and none are excluded.
///
/// If a polygon has both an include and an exclude flag, it will be excluded.
///
/// The way filtering works, a navigation mesh polygon must have at least one flag
/// set to ever be considered by a query. So a polygon with no flags will never
/// be considered.
///
/// Setting the include flags to 0 will result in all polygons being excluded.

/// For example, you could use some of the bits in these flags to represent a road, or
/// a water body, or grass and your query would determine whether they participate in
/// the path finding operations or not.
///
/// It also can be used to configure the cost of an area, so the path finding uses the
/// least expensive path (for example, you could flag grass as being more costly to
/// use than a road).
///
public class NavQueryFilter {
    var query: dtQueryFilter
    
    public var includeFlags: UInt16 {
        get { return query.getIncludeFlags() }
        set { query.setIncludeFlags(newValue) }
    }
    
    public var excludeFlags: UInt16 {
        get { return query.getExcludeFlags() }
        set { query.setExcludeFlags(newValue)}
    }
    public init () {
        query = dtAllocQueryFilter()
    }

    /// Sets the cost for an area when using this filter
    /// - Parameters:
    ///   - idx: The index of the area to set the cost to (there are 64 possible areas)
    ///   - cost: The cost, the default is 1.0
    public func setAreaCost (_ idx: Int32, cost: Float) {
        query.setAreaCost(Int32(idx), cost)
    }
    
    
    /// Returns the cost associated with an area when using this filter.
    /// - Parameter idx: The index of the area to set the cost to (there are 64 possible areas)
    /// - Returns: The cost of using that area.
    public func getAreaCost (_ idx: Int32) -> Float {
        query.getAreaCost(idx)
    }
    
    deinit {
        dtFreeQueryFilter (query)
    }
}
