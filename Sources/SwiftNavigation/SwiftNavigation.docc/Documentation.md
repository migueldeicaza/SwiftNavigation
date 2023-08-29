# ``SwiftNavigation``

SwiftNavigation provides mesh navigation construction and use for Swift and RealityKit applications. 

SwiftNavigation is a Swift binding to the popular RecastNavigation.   It can turn
your meshes or models into navigation meshes quickly.  You can use these to
find the paths between two points in your mesh, find nearby places in your mesh,
avoid obstacles or create agents that can seek targets in this mesh.

<!--@START_MENU_TOKEN@-->Menu<!--@END_MENU_TOKEN@-->

## Topics

### Getting Started

Generally you start by initializing a ``NavMeshBuilder`` with the data
from your model.  This can be either some raw data in the form of
vertices and triangles, or it can be a `ModelComponent` that you
loaded from RealityKit based on a number of configuration parameters
for your environment.

The initialization will perform the mesh computation (what is
originally called the "Recast" framework), and once it is done, you
can either save the navigation mesh, or you can get to work by getting
a ``NavMesh`` object (what was originally called a "Detour" object).

You can use the ``NavMesh`` to find valid locations in your navigation
mesh, or to trace a path between two points using a number of
parameters or create agents that will move in your mesh from one point
to another while avoding an overlap with other agents.

### Licensing

Contact `hello@xibbon.com` for licensing information.


