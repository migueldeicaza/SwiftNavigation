
#ifndef BRIDGING_H
#define BRIDGING_H 1
#include <stdint.h>
#include "Recast.h"

typedef enum  {
    BCODE_OK = 0,
    BCODE_ERR_MEMORY = 1,
    BCODE_ERR_RASTERIZE = 2,
    BCODE_ERR_BUILD_COMPACT_HEIGHTFIELD = 3,
    BCODE_ERR_BUILD_LAYER_REGIONS = 4,
    BCODE_ERR_BUILD_REGIONS_MONOTONE = 5,
    BCODE_ERR_BUILD_DISTANCE_FIELD = 6,
    BCODE_ERR_BUILD_REGIONS = 7,
    BCODE_ERR_ALLOC_CONTOUR = 8,
    BCODE_ERR_BUILD_CONTOUR = 9,
    BCODE_ERR_UNKNOWN = 10,
    BCODE_ERR_ALLOC_POLYMESH = 11,
    BCODE_ERR_BUILD_POLY_MESH = 12,
    BCODE_ERR_ALLOC_DETAIL_POLY_MESH = 13,
    BCODE_ERR_BUILD_DETAIL_POLY_MESH = 14
} BCodeStatus;

typedef enum {
    BD_OK = 0,
    BD_ERR_VERTICES = 1,
    BD_ERR_BUILD_NAVMESH = 2,
    BD_ERR_ALLOC_NAVMESH = 3,
    BD_ERR_INIT_NAVMESH = 4
} BDetourStatus;

struct BindingBulkResult {
    BCodeStatus code;
    float cs, ch;
    rcPolyMesh *poly_mesh;
    rcPolyMeshDetail *poly_mesh_detail;
    int max_verts_per_poly;
};

enum {
    FILTER_LOW_HANGING_OBSTACLES = 1,
    FILTER_LEDGE_SPANS = 2,
    FILTER_WALKABLE_LOW_HEIGHT_SPANS = 4,
    
    // 3 bits to choose these options
    PARTITION_MASK = 24,
    PARTITION_WATERSHED = 8,
    PARTITION_MONOTONE = 16,
    PARTITION_LAYER = 0
};

struct BindingBulkResult *bindingRunBulk(rcConfig *config, int flags, const float* verts, int numVerts, const int* tris, int numTris);
void bindingRelease (BindingBulkResult *data);
BDetourStatus bindingGenerateDetour (BindingBulkResult *data, float agentHeight, float agentRadius, float agentMaxclimb, void **result, int *result_size);

struct BindingVertsAndTriangles {
    int nverts;
    int ntris;
    float *verts;
    uint32_t *triangles;
};

struct BindingVertsAndTriangles *bindingExtractVertsAndTriangles (const BindingBulkResult *bbr);
void freeVertsAndTriangles (BindingVertsAndTriangles *data);


#endif
