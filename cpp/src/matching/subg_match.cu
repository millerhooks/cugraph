#include <gunrock/app/sm/sm_app.cuh>

#include <thrust/sequence.h>

#include "utilities/graph_utils.cuh"
#include "utilities/error_utils.h"
#include <cugraph.h>
#include <algo_types.h>

#include <iostream>
#include <type_traits>
#include <array>
#include <cstdint>

//#define _DEBUG_SM_

//
/**
 * @brief Subgraph matching. 
 * API for gunrock implementation.
 *
 * @tparam VertexT the indexing type for vertices
 * @tparam SizeT the type for sizes/dimensions
 * @tparam GValueT the type for edge weights
 * @param  graph_src input source graph (to search into); assumed undirected [in]
 * @param  graph_query input query graph (to search for); assumed undirected [in]
 * @param  subgraphs   Return number of subgraphs [out]
 * @param  stream the cuda stream [in / optional]
 */
template <typename VertexT,
          typename SizeT,
          typename GValueT>
gdf_error gdf_subgraph_matching_impl(gdf_graph *graph_src,
                                     gdf_graph *graph_query,
                                     VertexT* subgraphs,
                                     cudaStream_t stream = nullptr)
{
  static auto row_offsets_ = [](const gdf_graph* G){
    return static_cast<const SizeT*>(G->adjList->offsets->data);
  };

  static auto col_indices_ = [](const gdf_graph* G){
    return static_cast<const VertexT*>(G->adjList->indices->data);
  };

  static auto values_ = [](const gdf_graph* G){
    return static_cast<const GValueT*>(G->adjList->edge_data->data);
  };


  static auto nrows_ = [](const gdf_graph* G){
    return static_cast<SizeT>(G->adjList->offsets->size - 1);
  };

  static auto nnz_ = [](const gdf_graph* G){
    return static_cast<SizeT>(G->adjList->indices->size);
  };
  std::array<gdf_graph*, 2> arr_graph = {graph_src, graph_query};

  //check consistency of both graphs:
  //
  for(auto&& graph: arr_graph)
    {
      GDF_REQUIRE(graph != nullptr, GDF_INVALID_API_CALL);
    
      GDF_REQUIRE(graph->adjList != nullptr, GDF_INVALID_API_CALL);
    
      GDF_REQUIRE(row_offsets_(graph) != nullptr, GDF_INVALID_API_CALL);

      GDF_REQUIRE(col_indices_(graph) != nullptr, GDF_INVALID_API_CALL);
    
      auto type_id = graph->adjList->offsets->dtype;
      GDF_REQUIRE( type_id == GDF_INT32 || type_id == GDF_INT64, GDF_UNSUPPORTED_DTYPE);
  
      GDF_REQUIRE( type_id == graph->adjList->indices->dtype, GDF_UNSUPPORTED_DTYPE);
  
      const SizeT* p_d_row_offsets = row_offsets_(graph);
      const VertexT* p_d_col_ind = col_indices_(graph);
      const GValueT* p_d_values = values_(graph);

      assert( p_d_values );

      SizeT nnz = nnz_(graph);
      SizeT nrows = nrows_(graph);
    }

  //TODO: call into proper Gunrock API (non-existent, yet)
  //
  //below is the wrong API to call;
  //Gunrock has yet to properly expose one...
  //
  // auto t_elapsed = sm(nrows,
  //                     nnz,
  //                     p_d_row_offsets,
  //                     p_d_col_ind,
  //                     p_d_values,
  //                     1,
  //                     subgraphs);
    
  return GDF_SUCCESS;
}

/**
 * @brief Subgraph matching. 
 * API for gunrock implementation.
 *
 * @param  graph_src input source graph (to search into); assumed undirected [in]
 * @param  graph_query input query graph (to search for); assumed undirected [in]
 * @param  subgraphs   Return number of matched subgraphs [out]
 */
gdf_error gdf_subgraph_matching(gdf_graph *graph_src,
                                gdf_graph *graph_query,
                                gdf_column* subgraphs)

{
  static auto row_offsets_t_ = [](const gdf_graph* G){
    return G->adjList->offsets->dtype;
  };

  static auto col_indices_t_ = [](const gdf_graph* G){
    return G->adjList->indices->dtype;
  };

  static auto values_t_ = [](const gdf_graph* G){
    return G->adjList->edge_data->dtype;
  };

  
  auto subg_dtype = subgraphs->dtype;
  //auto ro_dtype   = row_offsets_t_(graph_src);//not yet necessary...possibly later, when smoke clears out
  auto ci_src_dtype   = col_indices_t_(graph_src);
  auto ci_qry_dtype   = col_indices_t_(graph_query);
  //auto v_dtype    = values_t_(graph_src);//not yet necessary...possibly later, when smoke clears out

  //currently Gunrock's API requires that graph's col indices and subgraphs must be same type:
  //
  GDF_REQUIRE( subg_dtype == ci_src_dtype, GDF_INVALID_API_CALL);
  GDF_REQUIRE( subg_dtype == ci_qry_dtype, GDF_INVALID_API_CALL);

  //TODO: hopefully multi-type-dispatch on various combos of types:
  //
  int* p_d_subg = static_cast<int*>(subgraphs->data);
  return gdf_subgraph_matching_impl<int, int, unsigned long>(graph_src, graph_query, p_d_subg);
}
