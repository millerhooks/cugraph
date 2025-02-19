# Copyright (c) 2019, NVIDIA CORPORATION.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import gc
from itertools import product

import numpy as np
import pytest

import cudf
import cugraph
from cugraph.tests import utils
import rmm
from rmm import rmm_config

# Temporarily suppress warnings till networkX fixes deprecation warnings
# (Using or importing the ABCs from 'collections' instead of from
# 'collections.abc' is deprecated, and in 3.8 it will stop working) for
# python 3.7.  Also, this import networkx needs to be relocated in the
# third-party group once this gets fixed.
import warnings
with warnings.catch_warnings():
    warnings.filterwarnings("ignore", category=DeprecationWarning)
    import networkx as nx


def compare_edges(cg, nxg, verts):
    src, dest, weight = cg.view_edge_list()
    assert weight is None
    assert len(src) == nxg.size()
    for i in range(len(src)):
        assert nxg.has_edge(verts[src[i]], verts[dest[i]])
    return True


def cugraph_call(M, verts):
    G = cugraph.Graph()
    rows = cudf.Series(M.row)
    cols = cudf.Series(M.col)
    G.add_edge_list(rows, cols, None)
    cu_verts = cudf.Series(verts)
    return cugraph.subgraph(G, cu_verts)


def nx_call(M, verts):
    G = nx.DiGraph(M)
    return nx.subgraph(G, verts)


DATASETS = ['../datasets/karate.csv',
            '../datasets/dolphins.csv',
            '../datasets/netscience.csv',
            '../datasets/email-Eu-core.csv']


# Test all combinations of default/managed and pooled/non-pooled allocation
@pytest.mark.parametrize('managed, pool',
                         list(product([False, True], [False, True])))
@pytest.mark.parametrize('graph_file', DATASETS)
def test_subgraph_extraction(managed, pool, graph_file):
    gc.collect()

    rmm.finalize()
    rmm_config.use_managed_memory = managed
    rmm_config.use_pool_allocator = pool
    rmm_config.initial_pool_size = 2 << 27
    rmm.initialize()

    assert(rmm.is_initialized())

    M = utils.read_csv_for_nx(graph_file)
    verts = np.zeros(3, dtype=np.int32)
    verts[0] = 0
    verts[1] = 1
    verts[2] = 17
    cu_sg = cugraph_call(M, verts)
    nx_sg = nx_call(M, verts)
    assert compare_edges(cu_sg, nx_sg, verts)
