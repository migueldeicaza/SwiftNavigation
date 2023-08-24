//
//  NavQueryFilter.swift
//  NavigationSample
//
//  Created by Miguel de Icaza on 8/23/23.
//

import Foundation
import CRecast

@available(macOS 13.3.0, *)

/// The filter is used to describe the flags that are included when doing polygon evaluation
/// you set the `includeFlags` and `excludeFlags` to match those attribtues in the
/// region areas to include or exclude from searches.
///
/// A polygon matches if the flags on the polygon include those in ``includeFlags``,
/// and does not contain one of the flags in ``excludeFlags``.
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
    
    deinit {
        dtFreeQueryFilter (query)
    }
}
