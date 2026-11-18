# video_autoscaler (RNF-02, elasticity)

Adds and removes replicas of `video_tool` from the depth of `video_queue`.

- Every `POLL_S` s (5) it reads `messages_ready` and `messages_unacknowledged`
  from the RabbitMQ management API.
- Jobs waiting: one replica per job (waiting + running), between `MIN_REPLICAS`
  (1) and `MAX_REPLICAS` (4).
- Queue idle (nothing waiting or running) for `SCALE_IN_DELAY_S` s (60): back to
  `MIN_REPLICAS`. Busy replicas are never removed.
- New replicas copy the container Compose created (image, environment,
  volumes, networks, limits) and keep the Compose labels, so
  `docker compose ps video_tool` lists them and `docker compose down` removes
  them. Only replicas created here are removed (label `picturas.autoscaled`).
- A removed replica gets SIGTERM, stops consuming and closes its connection;
  an unfinished job goes back to the queue.

The rule is in `scaling_rule.py` and has unit tests:

    cd Tools/autoscaler && python3 -m unittest discover -s tests -v

Logs: `docker compose logs -f video_autoscaler`.

Security: the service mounts `/var/run/docker.sock`, which gives it control of
the Docker host. It only runs inside the internal network, has no exposed
port and uses only the Python standard library; in production this access
would go through a restricted Docker socket proxy.

Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
