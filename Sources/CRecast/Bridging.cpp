//
// Wraps the bulk of the navigation, since Swift/C++ does not seem to be able to
// import certain definitions
//
#include "Bridging.h"
#include "Recast.h"
#include "RecastAlloc.h"
#include "RecastAssert.h"
#include "DetourNavMeshBuilder.h"
#include "DetourNavMesh.h"

#include <math.h>
#include <string.h>
#include <stdio.h>
#include <stdarg.h>
#include <unistd.h>

// This runs the pipeline from beginning to end, based on the sample code and
struct BindingBulkResult *bindingRunBulk(rcConfig *cfg, int flags, const float* verts, int nverts, const int* tris, int ntris)
{
    rcHeightfield *hf = nullptr;
    rcCompactHeightfield *chf = nullptr;
    rcContourSet *cset = nullptr;
    rcPolyMesh *poly_mesh = nullptr;
    rcPolyMeshDetail *detail_mesh = nullptr;
    rcContext ctx;

    if (false) 
    {
        unlink ("/tmp/imported.obj");
        FILE *o = fopen ("/tmp/imported.obj", "w");
        int i = 0;
        for (i = 0; i < nverts; i++){
            const float *v = &verts [i*3];

            fprintf (o, "v %g %g %g\n", v[0], v[1], v[2]);
        }
        int top = ntris*3;
        for (i = 0; i < top; i += 3) {
            fprintf (o, "f %d %d %d\n", tris [i]+1, tris[i+1]+1, tris [i+2]+1);
        }
        fclose (o);
    }

    // Allocate voxel heightfield where we rasterize our input data to.
    hf = rcAllocHeightfield ();
    if (hf == nullptr) {
        return NULL;
    }
    struct BindingBulkResult *result = (struct BindingBulkResult *) calloc (1, sizeof (struct BindingBulkResult));
    result->code = BCODE_ERR_UNKNOWN;
    
    // Save some data, in case we want to use it to generate a Detour package.
    result->max_verts_per_poly = cfg->maxVertsPerPoly;
    result->cs = cfg->cs;
    result->ch = cfg->ch;
    
    unsigned char *tri_areas;
    int partition;
    
    if (!rcCreateHeightfield(&ctx, *hf, cfg->width, cfg->height, cfg->bmin, cfg->bmax, cfg->cs, cfg->ch))
        goto exit1;
    
    tri_areas = (unsigned char*) calloc(ntris, sizeof (unsigned char));
    if (tri_areas == NULL){
        result->code = BCODE_ERR_MEMORY;
        goto exit1;
    }
    
    // Find triangles which are walkable based on their slope and rasterize them.
    // If your input data is multiple meshes, you can transform them here, calculate
    // the are type for each of the meshes and rasterize them.
    rcMarkWalkableTriangles(&ctx, cfg->walkableSlopeAngle, verts, nverts, tris, ntris, tri_areas);
    
    if (!rcRasterizeTriangles(&ctx, verts, nverts, tris, tri_areas, ntris, *hf, cfg->walkableClimb)){
        result->code = BCODE_ERR_RASTERIZE;
        goto exit1;
    }
    
    //
    // Step 3. Filter walkable surfaces.
    //
    // Once all geometry is rasterized, we do initial pass of filtering to
    // remove unwanted overhangs caused by the conservative rasterization
    // as well as filter spans where the character cannot possibly stand.
    if (flags & FILTER_LOW_HANGING_OBSTACLES)
        rcFilterLowHangingWalkableObstacles(&ctx, cfg->walkableClimb, *hf);
    if (flags & FILTER_LEDGE_SPANS)
        rcFilterLedgeSpans(&ctx, cfg->walkableHeight, cfg->walkableClimb, *hf);
    if (flags & FILTER_WALKABLE_LOW_HEIGHT_SPANS)
        rcFilterWalkableLowHeightSpans(&ctx, cfg->walkableHeight, *hf);
    
    //
    // Step 4. Partition walkable surface to simple regions.
    //
    // Compact the heightfield so that it is faster to handle from now on.
    // This will result more cache coherent data as well as the neighbours
    // between walkable cells will be calculated.
    chf = rcAllocCompactHeightfield();
    if (!chf){
        result->code = BCODE_ERR_MEMORY;
        goto exit1;
    }
    
    
    if (!rcBuildCompactHeightfield(&ctx, cfg->walkableHeight, cfg->walkableClimb, *hf, *chf)){
        result->code = BCODE_ERR_BUILD_COMPACT_HEIGHTFIELD;
        goto exit2;
    }
    if (hf){
        rcFreeHeightField (hf);
        hf = nullptr;
    }

    // Erode the walkable area by agent radius.
    rcErodeWalkableArea(&ctx, cfg->walkableRadius, *chf);
    
    partition = flags & PARTITION_MASK;
    if (partition == PARTITION_LAYER) {
        // Partition the walkable surface into simple regions without holes.
        if (!rcBuildLayerRegions(&ctx, *chf, 0, cfg->minRegionArea)){
            result->code = BCODE_ERR_BUILD_LAYER_REGIONS;
            goto exit2;
        }
    } else if (partition == PARTITION_MONOTONE) {
        // Partition the walkable surface into simple regions without holes.
        // Monotone partitioning does not need distancefield.
        if (!rcBuildRegionsMonotone(&ctx, *chf, 0, cfg->minRegionArea, cfg->mergeRegionArea)){
            result->code = BCODE_ERR_BUILD_REGIONS_MONOTONE;
            goto exit2;
        }
    } else if (partition == PARTITION_WATERSHED) {
        // Prepare for region partitioning, by calculating distance field along the walkable surface.
        if (!rcBuildDistanceField(&ctx, *chf)) {
            result->code = BCODE_ERR_BUILD_DISTANCE_FIELD;
            goto exit2;
        }
        // Partition the walkable surface into simple regions without holes.
        if (!rcBuildRegions(&ctx, *chf, 0, cfg->minRegionArea, cfg->mergeRegionArea)) {
            result->code = BCODE_ERR_BUILD_REGIONS;
            goto exit2;
        }
    }
    
    //
    // Step 5. Trace and simplify region contours.
    //
    cset = rcAllocContourSet();
    if (cset == NULL) {
        result->code = BCODE_ERR_ALLOC_CONTOUR;
        goto exit2;
    }
    if (!rcBuildContours(&ctx, *chf, cfg->maxSimplificationError, cfg->maxEdgeLen, *cset)){
        result->code = BCODE_ERR_BUILD_CONTOUR;
        goto exit3;
    }
    
    //
    // Step 6. Build polygons mesh from contours.
    //
    // Build polygon navmesh from the contours.
    poly_mesh = rcAllocPolyMesh();
    if (!poly_mesh) {
        result->code = BCODE_ERR_ALLOC_POLYMESH;
        goto exit3;
    }
    if (!rcBuildPolyMesh(&ctx, *cset, cfg->maxVertsPerPoly, *poly_mesh)){
        result->code = BCODE_ERR_BUILD_POLY_MESH;
        goto exit4;
    }
    //
    // Step 7. Create detail mesh which allows to access approximate height on each polygon.
    //
    detail_mesh = rcAllocPolyMeshDetail();
    if (!detail_mesh) {
        result->code = BCODE_ERR_ALLOC_DETAIL_POLY_MESH;
        goto exit4;
    }
    if (!rcBuildPolyMeshDetail(&ctx, *poly_mesh, *chf, cfg->detailSampleDist, cfg->detailSampleMaxError, *detail_mesh)){
        result->code = BCODE_ERR_BUILD_DETAIL_POLY_MESH;
        goto exit5;
    }
    rcFreeCompactHeightfield(chf);
    chf = nullptr;
    rcFreeContourSet(cset);
    cset = nullptr;
    
    // At this point the navigation mesh data is ready, you can access it from poly_mesh.
    // See duDebugDrawPolyMesh or dtCreateNavMeshData as examples how to access the data.
    
    result->code = BCODE_OK;
    result->poly_mesh = poly_mesh;
    result->poly_mesh_detail = detail_mesh;
    if (poly_mesh->nverts == 0) {
        printf ("poly_mesh returned zero vertices, not good");
    }
#if false
    {
        unlink ("/tmp/output.obj");
        FILE *o = fopen ("/tmp/output.obj", "w");
        int i = 0;
        for (i = 0; i < detail_mesh->nverts; i++){
            const float *v = &detail_mesh->verts[i * 3];

            fprintf (o, "v %g %g %g\n", v[0], v[1], v[2]);
        }
        fclose (o);
    }
#endif
    return result;
    
exit5:
    if (detail_mesh)
        rcFreePolyMeshDetail(detail_mesh);
exit4:
    if (poly_mesh)
        rcFreePolyMesh(poly_mesh);
exit3:
    if (cset)
        rcFreeContourSet(cset);
exit2:
    if (chf)
        rcFreeCompactHeightfield(chf);
exit1:
    if (hf)
        rcFreeHeightField (hf);
    return result;
}

void
bindingRelease (BindingBulkResult *data)
{
    if (data->poly_mesh)
        rcFreePolyMesh(data->poly_mesh);
    if (data->poly_mesh_detail)
        rcFreePolyMeshDetail(data->poly_mesh_detail);
    free (data);
}

//
// Generates a blob suitable to be passed to detour from a baked navigation mesh
// The first parameter is the result of calling bindingRunBulk
//
// Returns:
//   - The data is placed in the pointer in `result`, and the size of the blob
//     is stored in `result_size`
BDetourStatus
bindingGenerateDetour (BindingBulkResult *data, float agentHeight, float agentRadius, float agentMaxClimb, void **result, int *result_size)
{
    if (data->max_verts_per_poly > DT_VERTS_PER_POLYGON) {
        return BD_ERR_VERTICES;
    }
    unsigned char* navData = 0;
    int navDataSize = 0;
    rcPolyMesh *poly_mesh = data->poly_mesh;
    rcPolyMeshDetail *poly_mesh_detail = data->poly_mesh_detail;
    
    // TODO: we should make this customizable, currently, just set a value, any value that is not zero
    // on the area, which is necessary for queries to work (otherwise they get excluded)
    // probably should invoke a callback with the area, flags and i value and set the value accordingly
    // See: Sample_SoloMesh::handleBuild's  `Update poly flags from areas.` comment

    for (int i = 0; i < poly_mesh->npolys; ++i){
        poly_mesh->flags[i] = 1;
    }
    
    dtNavMeshCreateParams params;
    memset(&params, 0, sizeof(params));
    params.verts = poly_mesh->verts;
    params.vertCount = poly_mesh->nverts;
    params.polys = poly_mesh->polys;
    params.polyAreas = poly_mesh->areas;
    params.polyFlags = poly_mesh->flags;
    params.polyCount = poly_mesh->npolys;
    params.nvp = poly_mesh->nvp;
    params.detailMeshes = poly_mesh_detail->meshes;
    params.detailVerts = poly_mesh_detail->verts;
    params.detailVertsCount = poly_mesh_detail->nverts;
    params.detailTris = poly_mesh_detail->tris;
    params.detailTriCount = poly_mesh_detail->ntris;
    
//    params.offMeshConVerts = m_geom->getOffMeshConnectionVerts();
//    params.offMeshConRad = m_geom->getOffMeshConnectionRads();
//    params.offMeshConDir = m_geom->getOffMeshConnectionDirs();
//    params.offMeshConAreas = m_geom->getOffMeshConnectionAreas();
//    params.offMeshConFlags = m_geom->getOffMeshConnectionFlags();
//    params.offMeshConUserID = m_geom->getOffMeshConnectionId();
//    params.offMeshConCount = m_geom->getOffMeshConnectionCount();
    params.walkableHeight = agentHeight;
    params.walkableRadius = agentRadius;
    params.walkableClimb = agentMaxClimb;
    rcVcopy(params.bmin, poly_mesh->bmin);
    rcVcopy(params.bmax, poly_mesh->bmax);
    params.cs = data->cs;
    params.ch = data->ch;
    params.buildBvTree = true;
    
    if (!dtCreateNavMeshData(&params, &navData, &navDataSize)){
        dtCreateNavMeshData(&params, &navData, &navDataSize);
        return BD_ERR_BUILD_NAVMESH;
    }
    
    dtNavMesh *navMesh = dtAllocNavMesh();
    if (!navMesh){
        dtFree(navData);
        return BD_ERR_ALLOC_NAVMESH;
    }
    *result = navData;
    *result_size = navDataSize;
    return BD_OK;
}

// Returns the floats in SIMD3<Float> format, with one padding float at the end
BindingVertsAndTriangles *
bindingExtractVertsAndTriangles (const BindingBulkResult *bbr)
{
    rcPolyMesh *pmesh = bbr->poly_mesh;
    BindingVertsAndTriangles *ret = (BindingVertsAndTriangles *) calloc(1, sizeof (BindingVertsAndTriangles));
    
    // First allocate the vertices and faces - the faces need two iterations to
    // allocate the right size array.
    float *verts = (float *) calloc (bbr->poly_mesh->nverts*4, sizeof(float));
    if (verts == NULL) {
        freeVertsAndTriangles(ret);
        return NULL;
    }
    ret->verts = verts;
    ret->nverts = bbr->poly_mesh->nverts;
    const int npolys = pmesh->npolys;
    const int nvp = pmesh->nvp;
    int ntris = 0;
    for (int i = 0; i < npolys; ++i){
        int items = 0;
        const unsigned short* p = &pmesh->polys[i*nvp*2];
        for (int j = 2; j < nvp; ++j){
            if (p[j] == RC_MESH_NULL_IDX)
                break;
            ntris += 3;
        }
    }
    uint32_t *trisArray = (uint32_t *) calloc (ntris, sizeof(uint32_t));
    if (trisArray == NULL) {
        freeVertsAndTriangles(ret);
        return NULL;
    }
    ret->triangles = trisArray;
    ret->ntris = ntris;

    // Now extract the vertices and triangle information
    const float cs = pmesh->cs;
    const float ch = pmesh->ch;
    const float* orig = pmesh->bmin;

    const int nverts = pmesh->nverts;
    int k = 0;
    for (int i = 0; i < nverts; ++i) {
        const unsigned short* v = &pmesh->verts[i*3];
        verts [k++] = orig[0] + v[0]*cs;
        verts [k++] = orig[1] + (v[1]+1)*ch + 0.1f;
        verts [k++] = orig[2] + v[2]*cs;
        verts [k++] = 0;
    }
    
    k = 0;
    for (int i = 0; i < npolys; ++i){
        const unsigned short* p = &pmesh->polys[i*nvp*2];
        for (int j = 2; j < nvp; ++j){
            if (p[j] == RC_MESH_NULL_IDX)
                break;
            trisArray [k++] = p[0];
            trisArray [k++] = p[j-1];
            trisArray [k++] = p[j];
        }
    }
    return ret;
}

void
freeVertsAndTriangles (BindingVertsAndTriangles *data) {
    if (data->verts){
        free (data->verts);
        data->verts = NULL;
    }
    if (data->triangles){
        free (data->triangles);
        data->triangles = NULL;
    }
    free (data);
}
