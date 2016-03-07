cere selectinv(1) -- Select representative invocations for a region
==================================================================

## SYNOPSIS

```
cere selectinv [-h] --region REGION [--force]
```

## DESCRIPTION

**cere selectinv** selects representative invocations for a region and generates
the model to retrieve the region execution time from representative replay measures.
To achieve this, **cere selectinv** reads the trace generated by cere-trace(1)
and clusterize the invocations. One invocation per cluster is selected to
represent its cluster. The model needed to retrieve the region execution time
from these representatives invocations is also outputted. Finally **cere selectinv**
generates an image of the trace clustering.
 
## OPTIONS

  * `-h`:
    Prints a synopsis and a list of the most commonly used options.

  * `--region REGION`:
    Selects the region for which you want to select representative invocations.
    The list of valid regions can be displayed with the cere-regions(1) command.

  * `--force`:
    By default, **cere selectinv** does not re-select representative invocations
    if a previous selection exists. The **--force** flag forces the selection.

## OUTPUT FILES

  * `.cere/traces/REGION.invocations`:
    Each row correspond to a cluster with row N stands for the cluster N. Each
    row contains the cluster representative invocation, the invocation execution
    time in cycle and the part of the cluster in the total execution time of the
    region.

  * `.cere/plots/REGION_byPhase.png`:
    Image of the trace clustering for the selected region.

## COPYRIGHT

cere is Copyright (C) 2014-2015 Université de Versailles St-Quentin-en-Yvelines

## SEE ALSO

cere-regions(1) cere-trace(1) cere-configure(1) cere-replay(1)