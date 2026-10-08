# MAIDR Example: Directed Graph (ggplot2 + ggraph) [experimental]
# Demonstrates an accessible drawing of a directed graph.
#
# ggraph draws a graph as edges and node points over a layout. MAIDR reads a
# directed graph as the graph itself: Left and Right walk the nodes, and each
# announces what feeds it, what it feeds, and whether it is an input or an
# output of the whole graph, a branch point or a merge point, with that
# node's point outlined. The nodes' own attributes -- `stage` here -- are
# announced with them.

library(maidr)
library(ggplot2)
library(ggraph)
library(igraph)

pipeline <- graph_from_edgelist(
  rbind(
    c("load", "clean"),
    c("clean", "features"),
    c("clean", "labels"),
    c("features", "train"),
    c("labels", "train"),
    c("train", "evaluate")
  ),
  directed = TRUE
)
V(pipeline)$stage <- c("input", "prepare", "prepare", "prepare", "fit", "report")

p <- ggraph(pipeline, layout = "sugiyama") +
  geom_edge_link(
    arrow = arrow(length = unit(3, "mm")),
    end_cap = circle(4, "mm")
  ) +
  geom_node_point(size = 6, colour = "steelblue") +
  geom_node_text(aes(label = name), vjust = -1.4) +
  labs(title = "A Training Pipeline") +
  theme_void()

# Display with MAIDR accessibility features
show(p)
