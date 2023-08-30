# Building a Navigation Mesh

# What is a Navigation Mesh

A navigation mesh is a data structure that represents the walkable
surfaces of a 3D environment - that is, areas that are suitable for
the entities in your world to reach without causing visual glitches or feeling
odd to the user.

You can create a navigation mesh from an existing mesh that represents the
terrain or rooms that you want to navigate.   Then you provide the library with
information about the size of the entities that will navigate in this space, and
information about how much your entities can climb (for example, you might want
to prevent your entities to walk on a very steep wall).

Your mesh builder is created by initializing an instance of ``NavMeshBuilder``
with the data from your 3D model.  This can be either some raw data in the form
of vertices and triangles, or it can be a `ModelComponent` that you
loaded from RealityKit based on a number of configuration parameters
for your environment.

The other component that you need to provide a ``NavMeshBuilder.Config``
structure with the parameters that describe your environment.  This is where you
would configure things like how steep the angles are, how fine-grained you want
your mesh to be, the heigh of your agents and so on.

The initialization will perform the mesh computation (what is
originally called the "Recast" framework), and once it is done, you
can either save the navigation mesh, or you can get to work by getting
a ``NavMesh`` object (what was originally called a "Detour" object).


