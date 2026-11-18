"""RNF-02 (elasticity): when to add or remove video workers.

Pure function, no Docker or RabbitMQ, so it is unit-tested on its own.

- Scale out at once when jobs are waiting: one replica per job in the queue
  (waiting + running), between MIN and MAX.
- Scale in only when the queue has been completely idle (nothing waiting and
  nothing running) for SCALE_IN_DELAY seconds, back to MIN. Removing a replica
  while it works would throw the job back to the queue, so busy replicas are
  never removed.

Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
"""
import math
from dataclasses import dataclass
from typing import Optional, Tuple


@dataclass(frozen=True)
class Config:
    min_replicas: int = 1
    max_replicas: int = 4
    jobs_per_replica: int = 1  # the worker uses prefetch=1
    scale_in_delay_s: float = 60.0


def desired_replicas(ready: int, unacked: int, current: int, idle_since: Optional[float],
                     now: float, cfg: Config) -> Tuple[int, Optional[float]]:
    """Returns (replicas to run, new idle_since)."""
    busy = ready + unacked
    idle_since = (idle_since if idle_since is not None else now) if busy == 0 else None

    wanted = max(cfg.min_replicas,
                 min(cfg.max_replicas, math.ceil(busy / cfg.jobs_per_replica)))
    if ready > 0 and wanted > current:
        return wanted, idle_since
    if current < cfg.min_replicas:
        return cfg.min_replicas, idle_since
    if busy == 0 and current > cfg.min_replicas and now - idle_since >= cfg.scale_in_delay_s:
        return cfg.min_replicas, idle_since
    return current, idle_since
