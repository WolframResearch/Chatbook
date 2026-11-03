Here's how to work with graphs and networks in Wolfram Language, from building a graph to running common algorithms on it.

## Building a graph

A [`Graph`](paclet:ref/Graph) is created from a list of edges. Use `<->` (or `UndirectedEdge`) for undirected edges and `->` (or `DirectedEdge`) for directed ones:

```wl
g = Graph[{1 <-> 2, 2 <-> 3, 3 <-> 1, 3 <-> 4, 4 <-> 5},
  VertexLabels -> "Name"]
```

```wl
dg = Graph[{"a" -> "b", "b" -> "c", "c" -> "a", "c" -> "d"},
  VertexLabels -> Automatic, GraphLayout -> "LayeredDigraphEmbedding"]
```

You can also start from built-in families like `CompleteGraph[5]`, `GridGraph[{4, 4}]`, `RandomGraph[{20, 40}]`, or from curated data with `GraphData["PetersenGraph"]`.

### Weighted graphs

Weights are given with the `EdgeWeight` option:

```wl
wg = Graph[{1 <-> 2, 2 <-> 3, 1 <-> 3, 3 <-> 4},
  EdgeWeight -> {4, 1, 7, 2},
  EdgeLabels -> "EdgeWeight",
  VertexLabels -> "Name"]
```

## Basic properties

```wl
In[4]:= {VertexCount[g], EdgeCount[g]}

Out[4]= {5, 5}

In[5]:= VertexDegree[g]

Out[5]= {2, 2, 3, 2, 1}

In[6]:= ConnectedGraphQ[g]

Out[6]= True
```

The sum of the degrees is always twice the number of edges: $\sum_v \deg(v) = 2|E|$, and here $2 + 2 + 3 + 2 + 1 = 10 = 2 \times 5$.

## Paths and distances

| Task | Function | Example |
|:-----|:---------|:--------|
| Shortest path | `FindShortestPath` | `FindShortestPath[wg, 1, 4]` |
| Distance | `GraphDistance` | `GraphDistance[wg, 1, 4]` |
| All distances | `GraphDistanceMatrix` | `GraphDistanceMatrix[g]` |
| Diameter | `GraphDiameter` | `GraphDiameter[g]` |
| Hamiltonian cycle | `FindHamiltonianCycle` | `FindHamiltonianCycle[CompleteGraph[4]]` |

For the weighted graph above, the shortest path from 1 to 4 goes through 2 and 3, with total weight $4 + 1 + 2 = 7$, which is shorter than the direct route $1 \to 3 \to 4$ with weight $7 + 2 = 9$:

```wl
In[7]:= FindShortestPath[wg, 1, 4]

Out[7]= {1, 2, 3, 4}

In[8]:= GraphDistance[wg, 1, 4]

Out[8]= 7.
```

To highlight the path in the graph:

```wl
HighlightGraph[wg, PathGraph[FindShortestPath[wg, 1, 4]]]
```

## Centrality and communities

Centrality measures tell you which vertices are most "important":

- `DegreeCentrality` — the number of neighbors
- `ClosenessCentrality` — based on the average distance to other vertices
- `BetweennessCentrality` — how often a vertex lies on shortest paths
- `PageRankCentrality` — the PageRank algorithm, with damping factor $\alpha$ (usually $0.85$)

```wl
karate = ExampleData[{"NetworkGraph", "ZacharyKarateClub"}];
TakeLargestBy[Thread[VertexList[karate] -> BetweennessCentrality[karate]], Last, 3]
```

To find communities:

```wl
CommunityGraphPlot[karate, FindGraphCommunities[karate]]
```

## Trees and spanning trees

A minimum spanning tree connects all vertices with the smallest total edge weight:

```wl
FindSpanningTree[wg, EdgeLabels -> "EdgeWeight"]
```

For a graph with $n$ vertices, any spanning tree has exactly $n - 1$ edges.

## Directed acyclic graphs

```wl
tasks = Graph[{"design" -> "build", "build" -> "test", "design" -> "docs",
   "test" -> "release", "docs" -> "release"}];
AcyclicGraphQ[tasks]
TopologicalSort[tasks]
(* {"design", "build", "docs", "test", "release"} *)
```

Topological sort gives an order in which to do the tasks so that each task comes after all of its dependencies.

> If `TopologicalSort` returns unevaluated, the graph has a cycle. Use `FindCycle[g]` to find it.
