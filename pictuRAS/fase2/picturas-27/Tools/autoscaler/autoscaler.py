"""RNF-02 (elasticity): autoscaler for the video worker.

Every POLL_S seconds it reads the depth of TARGET_QUEUE from the RabbitMQ
management API and adds or removes replicas of TARGET_SERVICE through the
Docker Engine API (the Docker socket is mounted read-write). New replicas are
copies of the replica Docker Compose created (same image, environment,
volumes, networks and limits) with the Compose labels, so `docker compose ps`
lists them and `docker compose down` removes them. Only replicas this service
created are ever removed.

Uses only the Python standard library.
Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
"""
import base64
import http.client
import json
import os
import socket
import time
import urllib.parse
import urllib.request

from scaling_rule import Config, desired_replicas

PROJECT = os.getenv("COMPOSE_PROJECT", "picturas")
SERVICE = os.getenv("TARGET_SERVICE", "video_tool")
QUEUE = os.getenv("TARGET_QUEUE", "video_queue")
RABBIT_API = os.getenv("RABBITMQ_API", "http://rabbitmq:15672")
RABBIT_USER = os.getenv("RABBITMQ_USERNAME", "user")
RABBIT_PASS = os.getenv("RABBITMQ_PASSWORD", "password")
POLL_S = float(os.getenv("POLL_S", "5"))
STOP_TIMEOUT_S = int(os.getenv("STOP_TIMEOUT_S", "30"))
AUTO_LABEL = "picturas.autoscaled"
CFG = Config(
    min_replicas=int(os.getenv("MIN_REPLICAS", "1")),
    max_replicas=int(os.getenv("MAX_REPLICAS", "4")),
    scale_in_delay_s=float(os.getenv("SCALE_IN_DELAY_S", "60")),
)


def log(msg):
    print(f"[autoscaler] {time.strftime('%Y-%m-%dT%H:%M:%S')} {msg}", flush=True)


# ------------------------------------------------------------- Docker API
class UnixHTTPConnection(http.client.HTTPConnection):
    def __init__(self, path):
        super().__init__("localhost", timeout=60)
        self._path = path

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.connect(self._path)


def docker(method, path, body=None):
    conn = UnixHTTPConnection("/var/run/docker.sock")
    data = json.dumps(body) if body is not None else None
    conn.request(method, path, body=data, headers={"Content-Type": "application/json"})
    resp = conn.getresponse()
    raw = resp.read()
    conn.close()
    if resp.status >= 400:
        raise RuntimeError(f"Docker API {method} {path}: {resp.status} {raw[:200]!r}")
    return json.loads(raw) if raw else None


def replicas():
    filters = json.dumps({"label": [f"com.docker.compose.project={PROJECT}",
                                    f"com.docker.compose.service={SERVICE}"]})
    return docker("GET", "/containers/json?filters=" + urllib.parse.quote(filters))


def add_replica(template_id, number):
    tpl = docker("GET", f"/containers/{template_id}/json")
    cfg, host = tpl["Config"], tpl["HostConfig"]
    labels = dict(cfg.get("Labels") or {})
    labels.update({"com.docker.compose.container-number": str(number),
                   "com.docker.compose.oneoff": "False", AUTO_LABEL: "true"})
    networks = tpl["NetworkSettings"]["Networks"]
    first, *others = list(networks.items())
    # Compose may describe the same volume both ways; keep each target once
    mounts = host.get("Mounts") or []
    targets = {m.get("Target") for m in mounts}
    binds = [b for b in (host.get("Binds") or []) if b.split(":")[1] not in targets]
    body = {
        "Image": cfg["Image"], "Env": cfg.get("Env"), "Cmd": cfg.get("Cmd"),
        "WorkingDir": cfg.get("WorkingDir"), "Labels": labels,
        "HostConfig": {
            "Binds": binds, "Mounts": mounts,
            "NetworkMode": host.get("NetworkMode"),
            "NanoCpus": host.get("NanoCpus"), "Memory": host.get("Memory"),
            "RestartPolicy": {"Name": "no"},
        },
        "NetworkingConfig": {"EndpointsConfig": {first[0]: {"Aliases": [SERVICE]}}},
    }
    name = f"{PROJECT}-{SERVICE}-{number}"
    created = docker("POST", f"/containers/create?name={name}", body)
    for net, _ in others:
        docker("POST", f"/networks/{net}/connect",
               {"Container": created["Id"], "EndpointConfig": {"Aliases": [SERVICE]}})
    docker("POST", f"/containers/{created['Id']}/start")
    log(f"started {name}")


def remove_replica(container):
    name = container["Names"][0].lstrip("/")
    # SIGTERM first: the worker stops consuming and leaves (see video.py)
    docker("POST", f"/containers/{container['Id']}/stop?t={STOP_TIMEOUT_S}")
    docker("DELETE", f"/containers/{container['Id']}")
    log(f"removed {name}")


# ------------------------------------------------------------- RabbitMQ API
def queue_depth():
    auth = base64.b64encode(f"{RABBIT_USER}:{RABBIT_PASS}".encode()).decode()
    req = urllib.request.Request(f"{RABBIT_API}/api/queues/%2F/{QUEUE}",
                                 headers={"Authorization": f"Basic {auth}"})
    with urllib.request.urlopen(req, timeout=10) as r:
        q = json.loads(r.read())
    return q.get("messages_ready", 0), q.get("messages_unacknowledged", 0)


# ------------------------------------------------------------- loop
def scale_to(target, running):
    current = len(running)
    if target > current:
        template = next((c for c in running if AUTO_LABEL not in c["Labels"]), running[0])
        used = {int(c["Labels"].get("com.docker.compose.container-number", 0)) for c in running}
        numbers = (n for n in range(1, 1000) if n not in used)
        for _ in range(target - current):
            add_replica(template["Id"], next(numbers))
    elif target < current:
        auto = sorted((c for c in running if c["Labels"].get(AUTO_LABEL) == "true"),
                      key=lambda c: c["Created"], reverse=True)
        for c in auto[:current - target]:
            remove_replica(c)


def main():
    log(f"watching {QUEUE} -> {SERVICE} (min={CFG.min_replicas}, max={CFG.max_replicas}, "
        f"scale-in after {CFG.scale_in_delay_s:.0f} s idle)")
    idle_since = None
    while True:
        try:
            ready, unacked = queue_depth()
            running = replicas()
            if not running:
                log(f"no {SERVICE} container running yet")
            else:
                target, idle_since = desired_replicas(ready, unacked, len(running), idle_since,
                                                      time.time(), CFG)
                if target != len(running):
                    log(f"ready={ready} unacked={unacked} replicas={len(running)} -> {target}")
                    scale_to(target, running)
        except Exception as e:  # noqa: BLE001 - keep watching
            log(f"error: {e}")
        time.sleep(POLL_S)


if __name__ == "__main__":
    main()
