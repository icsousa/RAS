#!/usr/bin/env python3
"""Medições da Fase 2 (PL3-G7) contra a stack real em Docker.

Usado para a medição de BASE (código original) e para a medição FINAL (após a
refatoração), sempre nas mesmas condições. Só usa a biblioteca padrão do Python,
mais `docker`, `curl` e `ffmpeg` no PATH.

Uso (a partir da pasta picturas-27, com a stack a correr):

    python3 ../medicoes/medir.py videos                      # gera os vídeos de teste (1x)
    python3 ../medicoes/medir.py upload      --etiqueta base  # RNF-01: M1, M2, M4
    python3 ../medicoes/medir.py concorrencia --etiqueta base # RNF-01: M3 (ver README)
    python3 ../medicoes/medir.py elasticidade --etiqueta base # RNF-02: E1-E5

Os resultados ficam em ../medicoes/resultados/<etiqueta>/ (JSON e CSV).

Escrito com apoio de IA (Claude) e revisto pelo grupo; ver o relatório, secção
"Utilização de IA".
"""
import argparse
import concurrent.futures as cf
import datetime as dt
import json
import os
import re
import ssl
import statistics
import subprocess
import sys
import threading
import time
import urllib.request
import uuid
from base64 import b64encode
from pathlib import Path

AQUI = Path(__file__).resolve().parent
VIDEOS = AQUI / "videos"
BASE_URL = os.environ.get("PICTURAS_URL", "https://localhost:8080/api-gateway")
RABBIT = os.environ.get("RABBIT_URL", "http://localhost:15672")
RABBIT_AUTH = "Basic " + b64encode(b"user:password").decode()
SERVICOS_UPLOAD = ["api_gateway", "projects", "img_storage"]
CTX = ssl.create_default_context()
CTX.check_hostname = False
CTX.verify_mode = ssl.CERT_NONE  # certificado autoassinado da stack local


# ---------------------------------------------------------------- utilitários
def agora():
    return time.time()


def log(*a):
    print(f"[{dt.datetime.now():%H:%M:%S}]", *a, flush=True)


def pasta_resultados(etiqueta):
    p = AQUI / "resultados" / etiqueta
    p.mkdir(parents=True, exist_ok=True)
    return p


def guardar(etiqueta, nome, dados):
    f = pasta_resultados(etiqueta) / nome
    f.write_text(json.dumps(dados, indent=2, ensure_ascii=False))
    log("resultado guardado em", f)


def api(metodo, caminho, corpo=None, token=None, headers=None):
    h = {"Content-Type": "application/json"}
    if token:
        h["Authorization"] = f"Bearer {token}"
    h.update(headers or {})
    data = json.dumps(corpo).encode() if corpo is not None else None
    req = urllib.request.Request(BASE_URL + caminho, data=data, method=metodo, headers=h)
    try:
        with urllib.request.urlopen(req, context=CTX, timeout=120) as r:
            txt = r.read().decode() or "null"
            return r.status, json.loads(txt), dict(r.headers)
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode(errors="replace"), dict(e.headers)


def rabbit(caminho):
    req = urllib.request.Request(RABBIT + caminho, headers={"Authorization": RABBIT_AUTH})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.loads(r.read())


def criar_utilizador(tipo):
    email = f"medicao-{uuid.uuid4().hex[:8]}@picturas.test"
    st, r, _ = api("POST", "/users", {"name": "Medicao", "email": email,
                                      "password": "medicao123", "type": tipo})
    if st != 201:
        sys.exit(f"Falha a registar utilizador ({st}): {r}")
    return r["user"]["_id"], r["jwt"]


def criar_projeto(uid, token, nome=None):
    st, r, _ = api("POST", f"/projects/{uid}", {"name": nome or f"m-{uuid.uuid4().hex[:6]}"}, token)
    if st != 201:
        sys.exit(f"Falha a criar projeto ({st}): {r}")
    return r["_id"]


def versao(uid, pid, token):
    st, r, _ = api("GET", f"/projects/{uid}/{pid}", token=token)
    return int(r.get("version", 0)) if isinstance(r, dict) else 0


def upload_curl(uid, pid, token, ficheiro, ver):
    """Envia o vídeo com curl (que lê o ficheiro em streaming). Devolve dict."""
    url = f"{BASE_URL}/projects/{uid}/{pid}/video"
    cmd = ["curl", "-sk", "-o", "/dev/null", "-w",
           "%{http_code} %{time_total} %{size_upload}",
           "-H", f"Authorization: Bearer {token}", "-H", f"X-Project-Version: {ver}",
           "-F", f"video=@{ficheiro};type=video/mp4", url]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout.split()
    if len(out) < 3:
        return {"status": 0, "tempo_s": None, "bytes_enviados": None}
    return {"status": int(out[0]), "tempo_s": float(out[1]), "bytes_enviados": int(float(out[2]))}


# ---------------------------------------------------------------- docker
def compose(*args, capture=True):
    return subprocess.run(["docker", "compose", *args], capture_output=capture, text=True)


def reiniciar_servicos_upload(uid, token):
    """Restart the upload services, then nginx, and wait until the API answers.

    nginx resolves `api_gateway` only at startup; a restarted container may get
    a new IP, so nginx must be restarted too or it answers 502.
    Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
    """
    compose("restart", *SERVICOS_UPLOAD)
    compose("restart", "nginx")
    limite = agora() + 120
    while agora() < limite:
        try:
            # listing the user's projects goes through nginx, gateway and projects
            st = api("GET", f"/projects/{uid}", token=token)[0]
        except Exception:  # noqa: BLE001 - connection refused while starting
            st = 0
        if st == 200:
            time.sleep(5)  # let img_storage finish connecting too
            return
        time.sleep(1)
    sys.exit("A stack não voltou a responder depois do reinício.")


def contentores(servico):
    return [c for c in compose("ps", "-q", servico).stdout.split() if c]


def mem_cgroup(cid, ficheiro):
    r = subprocess.run(["docker", "exec", cid, "cat", f"/sys/fs/cgroup/{ficheiro}"],
                       capture_output=True, text=True)
    try:
        return int(r.stdout.strip())
    except ValueError:
        return None


class AmostradorStats(threading.Thread):
    """Lê `docker stats` em contínuo (≈1 amostra/s) e guarda o máximo por contentor."""

    def __init__(self, ids):
        super().__init__(daemon=True)
        self.ids, self.max_mb, self.amostras = ids, {i: 0.0 for i in ids}, []
        self.proc = None

    def run(self):
        self.proc = subprocess.Popen(
            ["docker", "stats", "--format", "{{.ID}};{{.MemUsage}};{{.CPUPerc}}", *self.ids],
            stdout=subprocess.PIPE, text=True)
        for linha in self.proc.stdout:
            linha = re.sub(r"\x1b\[[0-9;]*[A-Za-z]", "", linha).strip()
            partes = linha.split(";")
            if len(partes) != 3:
                continue
            cid, mem, cpu = partes
            mb = para_mb(mem.split("/")[0])
            for i in self.ids:
                if i.startswith(cid) or cid.startswith(i[:12]):
                    self.max_mb[i] = max(self.max_mb[i], mb)
            self.amostras.append((agora(), cid, mb, cpu))

    def parar(self):
        if self.proc:
            self.proc.terminate()


def para_mb(txt):
    m = re.match(r"\s*([\d.]+)\s*([KMG]i?B|B)", txt)
    if not m:
        return 0.0
    v, u = float(m.group(1)), m.group(2)
    return v * {"B": 1 / 2**20, "KiB": 1 / 1024, "KB": 1 / 1024, "MiB": 1, "MB": 1,
                "GiB": 1024, "GB": 1024}[u]


# ---------------------------------------------------------------- vídeos
def gerar_video(nome, segundos, mb_alvo=None, largura=1280, altura=720):
    VIDEOS.mkdir(exist_ok=True)
    f = VIDEOS / nome
    if f.exists():
        return f
    log(f"a gerar {f.name} ({segundos} s{f', ~{mb_alvo} MB' if mb_alvo else ''})…")
    cmd = ["ffmpeg", "-v", "error", "-y", "-f", "lavfi",
           "-i", f"testsrc2=size={largura}x{altura}:rate=30",
           "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=44100", "-t", str(segundos)]
    if mb_alvo:
        kbps = int(mb_alvo * 8 * 1024 / segundos) - 130
        cmd += ["-vf", "noise=alls=60:allf=t", "-c:v", "libx264", "-preset", "ultrafast",
                "-b:v", f"{kbps}k", "-minrate", f"{kbps}k", "-maxrate", f"{kbps}k",
                "-bufsize", f"{kbps}k", "-x264-params", "nal-hrd=cbr:force-cfr=1"]
    else:
        cmd += ["-c:v", "libx264", "-preset", "veryfast"]
    cmd += ["-c:a", "aac", "-b:a", "128k", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(f)]
    subprocess.run(cmd, check=True)
    log(f"  {f.name}: {f.stat().st_size / 2**20:.0f} MB")
    return f


def cmd_videos(_):
    gerar_video("v100.mp4", 50, 95)      # perfil free: ≤ 60 s e ≤ 100 MB
    gerar_video("v500.mp4", 300, 500)    # premium
    gerar_video("v1000.mp4", 590, 1000)  # premium: ≤ 600 s e ≤ 1 GB
    gerar_video("v60s.mp4", 60)          # elasticidade: trabalho de referência
    lixo = VIDEOS / "lixo300.mp4"        # M4: não é um vídeo, só bytes
    if not lixo.exists():
        with open(lixo, "wb") as fh:
            fh.truncate(300 * 2**20)
    log("vídeos prontos em", VIDEOS)


# ---------------------------------------------------------------- RNF-01
def medir_um_upload(uid, token, ficheiro, reiniciar):
    if reiniciar:
        reiniciar_servicos_upload(uid, token)
    ids = {s: contentores(s)[0] for s in SERVICOS_UPLOAD}
    repouso = {s: mem_cgroup(c, "memory.current") for s, c in ids.items()}
    amost = AmostradorStats(list(ids.values()))
    amost.start()
    time.sleep(1.5)
    pid = criar_projeto(uid, token)
    r = upload_curl(uid, pid, token, ficheiro, versao(uid, pid, token))
    time.sleep(2)
    amost.parar()
    pico = {s: mem_cgroup(c, "memory.peak") for s, c in ids.items()}
    res = {"ficheiro": ficheiro.name, "mb": round(ficheiro.stat().st_size / 2**20), **r,
           "por_servico": {}}
    total = 0.0
    for s, c in ids.items():
        if pico[s] is not None and repouso[s] is not None:
            extra = (pico[s] - repouso[s]) / 2**20
            fonte = "cgroup memory.peak"
        else:
            extra = amost.max_mb[c] - (repouso[s] or 0) / 2**20
            fonte = "docker stats (1 s)"
        res["por_servico"][s] = {"extra_mb": round(extra, 1), "fonte": fonte}
        total += max(extra, 0)
    res["m1_extra_total_mb"] = round(total, 1)
    return res


def cmd_upload(a):
    uid, token = criar_utilizador("premium")
    resultados = []
    for nome in ["v100.mp4", "v500.mp4", "v1000.mp4"]:
        f = VIDEOS / nome
        if not f.exists():
            sys.exit("Faltam vídeos: corra primeiro `medir.py videos`.")
        for rep in range(a.repeticoes):
            log(f"M1/M2 {nome} repetição {rep + 1}/{a.repeticoes}")
            r = medir_um_upload(uid, token, f, reiniciar=True)
            log(f"  status={r['status']} t={r['tempo_s']} s  RAM extra={r['m1_extra_total_mb']} MB")
            resultados.append(r)
    resumo = {}
    for nome in ["v100.mp4", "v500.mp4", "v1000.mp4"]:
        rs = [r for r in resultados if r["ficheiro"] == nome and r["status"] in (200, 201, 204)]
        if rs:
            resumo[nome] = {"m1_mediana_mb": statistics.median(r["m1_extra_total_mb"] for r in rs),
                            "m2_mediana_s": statistics.median(r["tempo_s"] for r in rs),
                            "ok": len(rs), "n": a.repeticoes}
        else:  # no run succeeded (e.g. OOM): keep it visible in the summary
            resumo[nome] = {"ok": 0, "n": a.repeticoes,
                            "estados": [r["status"] for r in resultados if r["ficheiro"] == nome]}
    # Save M1/M2 before M4, so a failure there does not lose them
    guardar(a.etiqueta, "rnf01_upload.json",
            {"quando": dt.datetime.now().isoformat(), "resumo": resumo, "m4": None,
             "execucoes": resultados})
    # M4: 300 MB enviados por um utilizador free (limite 100 MB); abaixo dos
    # 1100m do nginx, que já recusa pelo Content-Length acima disso.
    # Restart first: a previous OOM may have left the gateway down.
    reiniciar_servicos_upload(uid, token)
    log("M4: 300 MB com o perfil free")
    fuid, ftoken = criar_utilizador("free")
    fpid = criar_projeto(fuid, ftoken)
    m4 = upload_curl(fuid, fpid, ftoken, VIDEOS / "lixo300.mp4", versao(fuid, fpid, ftoken))
    m4["bytes_enviados_mb"] = round((m4["bytes_enviados"] or 0) / 2**20, 1)
    log(f"  status={m4['status']} lidos={m4['bytes_enviados_mb']} MB em {m4['tempo_s']} s")
    guardar(a.etiqueta, "rnf01_upload.json",
            {"quando": dt.datetime.now().isoformat(), "resumo": resumo, "m4": m4,
             "execucoes": resultados})


def cmd_concorrencia(a):
    """M3: N carregamentos de 1 GB em paralelo, com os serviços limitados a 2 GB
    (usar o override docker-compose.medicoes.yaml)."""
    f = VIDEOS / "v1000.mp4"
    uid, token = criar_utilizador("premium")
    res = {}
    for n in a.niveis:
        reiniciar_servicos_upload(uid, token)
        pids = [criar_projeto(uid, token) for _ in range(n)]
        log(f"M3: {n} carregamentos de 1 GB em paralelo")
        with cf.ThreadPoolExecutor(n) as ex:
            rs = list(ex.map(lambda p: upload_curl(uid, p, token, f, versao(uid, p, token)), pids))
        ok = sum(r["status"] in (200, 201, 204) for r in rs)
        reinicios = {s: compose("ps", "--format", "{{.Status}}", s).stdout.strip()
                     for s in SERVICOS_UPLOAD}
        log(f"  {ok}/{n} terminaram com sucesso")
        res[str(n)] = {"ok": ok, "estados": [r["status"] for r in rs],
                       "tempos_s": [r["tempo_s"] for r in rs], "estado_servicos": reinicios}
    m3 = max([int(n) for n, r in res.items() if r["ok"] == int(n)] or [0])
    guardar(a.etiqueta, "rnf01_concorrencia.json",
            {"quando": dt.datetime.now().isoformat(), "m3": m3, "niveis": res})


# ---------------------------------------------------------------- RNF-02
def filas_video():
    filas = {}
    for q in rabbit("/api/queues/%2F"):
        if q["name"].startswith("video"):
            filas[q["name"]] = {"prontas": q.get("messages_ready", 0),
                                "em_curso": q.get("messages_unacknowledged", 0),
                                "consumidores": q.get("consumers", 0)}
    return filas


def preparar_projeto_video(uid, token, video, brilho=1.2):
    pid = criar_projeto(uid, token)
    r = upload_curl(uid, pid, token, video, versao(uid, pid, token))
    if r["status"] not in (200, 201, 204):
        sys.exit(f"Falha no upload do vídeo de teste: {r}")
    st, t, _ = api("POST", f"/projects/{uid}/{pid}/tool",
                   {"procedure": "brightness", "params": {"brightness": brilho}}, token,
                   {"X-Project-Version": str(versao(uid, pid, token))})
    if st not in (200, 201):
        sys.exit(f"Falha a adicionar ferramenta ({st}): {t}")
    st, p, _ = api("GET", f"/projects/{uid}/{pid}", token=token)
    return pid, p["imgs"][0]["_id"]


class ColetorLogs(threading.Thread):
    """Keeps a copy of the logs of every video container while it exists.

    The autoscaler removes extra replicas when the queue empties, and their logs
    go with them, so reading the logs only at the end misses their jobs.
    Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
    """

    def __init__(self, desde, intervalo=3):
        super().__init__(daemon=True)
        self.desde, self.intervalo = desde, intervalo
        self.textos, self.parar = {}, threading.Event()

    def recolher(self):
        nomes = subprocess.run(["docker", "ps", "--filter", "name=video", "--format", "{{.Names}}"],
                               capture_output=True, text=True).stdout.split()
        for n in nomes:
            r = subprocess.run(["docker", "logs", "--timestamps", "--since", self.desde, n],
                               capture_output=True, text=True)
            if r.returncode == 0:
                self.textos[n] = r.stdout + r.stderr

    def run(self):
        while not self.parar.wait(self.intervalo):
            self.recolher()

    def terminar(self):
        self.parar.set()
        self.join()
        self.recolher()
        return self.textos


def logs_video(textos):
    """Linhas `[video] msg=... preview=...` e `ok` dos contentores de vídeo.

    A pré-visualização identifica-se pelo prefixo `preview-` do id da mensagem,
    porque a linha `ok` não diz se o trabalho era uma pré-visualização."""
    eventos = []
    for s, out in textos.items():
        for linha in out.splitlines():
            m = re.match(r"(\S+)\s+\[video\] msg=(\S+) (preview=(\w+)|ok)", linha)
            if not m:
                continue
            ts = dt.datetime.fromisoformat(m.group(1)[:26].rstrip("Z")).replace(
                tzinfo=dt.timezone.utc).timestamp()
            tipo = "fim" if m.group(3) == "ok" else "inicio"
            eventos.append({"t": ts, "msg": m.group(2), "tipo": tipo,
                            "preview": m.group(2).startswith("preview-"), "servico": s})
    return sorted(eventos, key=lambda e: e["t"])


def cmd_elasticidade(a):
    video = VIDEOS / "v60s.mp4"
    if not video.exists():
        sys.exit("Falta v60s.mp4: corra primeiro `medir.py videos`.")
    uid, token = criar_utilizador("premium")
    log(f"a preparar {a.trabalhos} projetos de processamento e {a.previews} de pré-visualização…")
    proc = [preparar_projeto_video(uid, token, video) for _ in range(a.trabalhos)]
    # each preview project gets a slightly different brightness, so every
    # request misses the preview cache (same video + tools = same cache key)
    prev = [preparar_projeto_video(uid, token, video, round(1.2 + 0.01 * (i + 1), 2))
            for i in range(a.previews)]
    log("à espera que a fila esteja vazia e o número de workers estabilize (30 s)…")
    time.sleep(30)

    linha_tempo, parar = [], threading.Event()

    def amostrar():
        while not parar.is_set():
            try:
                linha_tempo.append({"t": agora(), "filas": filas_video()})
            except Exception as e:  # noqa: BLE001
                linha_tempo.append({"t": agora(), "erro": str(e)})
            time.sleep(1)

    th = threading.Thread(target=amostrar, daemon=True)
    th.start()
    desde = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    coletor = ColetorLogs(desde)
    coletor.start()
    t0 = agora()

    def processar(par):
        pid, _ = par
        return api("POST", f"/projects/{uid}/{pid}/process", {}, token,
                   {"X-Project-Version": str(versao(uid, pid, token))})[0]

    with cf.ThreadPoolExecutor(8) as ex:
        estados = list(ex.map(processar, proc))
    log(f"{a.trabalhos} trabalhos injetados em {agora() - t0:.1f} s; estados {set(estados)}")

    pedidos_preview = []
    for i, (pid, img) in enumerate(prev):
        time.sleep(a.intervalo_preview)
        t = agora()
        st = api("POST", f"/projects/{uid}/{pid}/preview/{img}", {}, token,
                 {"X-Project-Version": str(versao(uid, pid, token))})[0]
        pedidos_preview.append({"t": t, "status": st})
    log("pré-visualizações pedidas; à espera que as filas esvaziem…")

    while True:
        time.sleep(2)
        f = filas_video()
        if all(q["prontas"] == 0 and q["em_curso"] == 0 for q in f.values()):
            break
        if agora() - t0 > a.limite:
            log("limite de tempo atingido")
            break
    t_vazia = agora()
    log(f"filas vazias ao fim de {t_vazia - t0:.0f} s; a observar a contração ({a.repouso} s)…")
    time.sleep(a.repouso)
    parar.set()
    th.join()

    stats = subprocess.run(
        ["docker", "stats", "--no-stream", "--format", "{{.Name}};{{.CPUPerc}};{{.MemUsage}}"],
        capture_output=True, text=True).stdout.splitlines()
    repouso = [s.split(";") for s in stats if "video" in s]

    ev = logs_video(coletor.terminar())
    fins = [e for e in ev if e["tipo"] == "fim" and not e["preview"]]
    inicios_prev = [e for e in ev if e["tipo"] == "inicio" and e["preview"]]
    consumidores = [(p["t"], sum(q["consumidores"] for n, q in p["filas"].items()
                                 if "preview" not in n))
                    for p in linha_tempo if "filas" in p]
    c_min = consumidores[0][1] if consumidores else 1
    c_max = max((c for _, c in consumidores), default=c_min)
    t_exp = next((t for t, c in consumidores if c > c_min), None)
    t_contr = next((t for t, c in consumidores if t >= t_vazia and c <= c_min), None)
    duracao = (max(e["t"] for e in fins) - t0) if fins else None
    esperas = [round(i["t"] - p["t"], 1) for p, i in zip(pedidos_preview, inicios_prev)]

    resumo = {
        "E1_expansao_s": round(t_exp - t0, 1) if t_exp else "não escala",
        "E2_contracao_s": ("não aplicável (fixo)" if c_max == c_min else
                           round(t_contr - t_vazia, 1) if t_contr else f"> {a.repouso}"),
        "E3_debito_videos_por_min": round(len(fins) / duracao * 60, 2) if duracao else None,
        "E3_trabalhos_concluidos": len(fins),
        "E4_espera_preview_s": esperas,
        "E4_p95_s": (sorted(esperas)[max(0, int(round(0.95 * len(esperas))) - 1)]
                     if esperas else None),
        "E5_repouso": repouso,
        "workers_min_max": [c_min, c_max],
    }
    log(json.dumps(resumo, ensure_ascii=False))
    guardar(a.etiqueta, "rnf02_elasticidade.json",
            {"quando": dt.datetime.now().isoformat(), "resumo": resumo,
             "t0": t0, "t_filas_vazias": t_vazia, "estados_process": estados,
             "pedidos_preview": pedidos_preview, "eventos_worker": ev,
             "linha_tempo": linha_tempo})
    with open(pasta_resultados(a.etiqueta) / "rnf02_linha_tempo.csv", "w") as fh:
        fh.write("t_s,fila,prontas,em_curso,consumidores\n")
        for p in linha_tempo:
            for n, q in p.get("filas", {}).items():
                fh.write(f"{p['t'] - t0:.1f},{n},{q['prontas']},{q['em_curso']},{q['consumidores']}\n")


# ---------------------------------------------------------------- main
def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = p.add_subparsers(dest="cmd", required=True)
    sp.add_parser("videos").set_defaults(f=cmd_videos)
    u = sp.add_parser("upload")
    u.add_argument("--etiqueta", required=True)
    u.add_argument("--repeticoes", type=int, default=5)
    u.set_defaults(f=cmd_upload)
    c = sp.add_parser("concorrencia")
    c.add_argument("--etiqueta", required=True)
    c.add_argument("--niveis", type=int, nargs="+", default=[1, 2, 4, 8])
    c.set_defaults(f=cmd_concorrencia)
    e = sp.add_parser("elasticidade")
    e.add_argument("--etiqueta", required=True)
    e.add_argument("--trabalhos", type=int, default=20)
    e.add_argument("--previews", type=int, default=10)
    e.add_argument("--intervalo-preview", type=float, default=5)
    e.add_argument("--repouso", type=int, default=300, help="segundos a observar após esvaziar")
    e.add_argument("--limite", type=int, default=3600)
    e.set_defaults(f=cmd_elasticidade)
    a = p.parse_args()
    a.f(a)


if __name__ == "__main__":
    main()
