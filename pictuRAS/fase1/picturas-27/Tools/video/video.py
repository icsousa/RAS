"""Worker de vídeo do PictuRAS (Fase 1 — MVP de vídeo).

Consome pedidos da fila `video_queue`, executa a operação com FFmpeg e publica progresso,
sucesso ou falha na fila `video_results_queue`, consumida pelo serviço projects.

Decisões: DA-02 (um worker para as cinco operações), DA-03 (progresso por mensagens),
DA-04 (ficheiros no volume partilhado), DQ-006 (falha rápida por tempo/memória).
"""
import datetime
import json
import os
import queue
import threading
import time
import traceback

import operations
import probe
from runner import CANCELLED, PROCESSING_ERROR, CancelCheck, JobError

REQUEST_QUEUE = os.getenv("VIDEO_REQUEST_QUEUE", "video_queue")
RESULTS_QUEUE = os.getenv("VIDEO_RESULTS_QUEUE", "video_results_queue")
EXCHANGE = "picturas"
DATA_ROOT = os.path.realpath(os.getenv("VIDEO_DATA_ROOT", "/app/images"))
DEFAULT_TIMEOUT = float(os.getenv("VIDEO_JOB_TIMEOUT_SEC", "1800"))
SPEED_TIMEOUT = float(os.getenv("VIDEO_SPEED_TIMEOUT_SEC", "120"))  # REQ-VID-SPD-006
DEFAULT_MEM_MB = int(os.getenv("VIDEO_MEMORY_LIMIT_MB", "4096"))  # REQ-VID-STATUS-005
PROGRESS_INTERVAL = float(os.getenv("VIDEO_PROGRESS_INTERVAL_SEC", "1"))


def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def _inside_root(path):
    real = os.path.realpath(path)
    return real == DATA_ROOT or real.startswith(DATA_ROOT + os.sep)


def process_job(request, publish):
    """Processa um pedido. `publish(dict)` envia uma mensagem de resultado/progresso.

    Separado do RabbitMQ para poder ser testado diretamente.
    """
    started = time.monotonic()
    job_id = request.get("jobId")
    procedure = request.get("procedure")
    p = request.get("parameters") or {}
    base = {"jobId": job_id, "correlationId": request.get("messageId"), "procedure": procedure}

    def send(kind, **extra):
        publish({**base, "type": kind, "timestamp": now_iso(), **extra})

    try:
        inp, out, work = p.get("inputVideoURI"), p.get("outputVideoURI"), p.get("workDir")
        if not all([inp, out, work]) or not all(_inside_root(x) for x in (inp, out, work)):
            raise JobError("invalid_params", "Caminhos de ficheiro inválidos")
        if procedure not in operations.OPERATIONS:
            raise JobError("invalid_params", f"Operação desconhecida: {procedure}")

        timeout = float(p.get("timeoutSec") or (SPEED_TIMEOUT if procedure == "video_speed" else DEFAULT_TIMEOUT))
        check = CancelCheck(os.path.join(work, "CANCEL"), timeout)
        check.raise_if_needed()  # cancelado enquanto estava em fila

        src = probe.video_info(inp)
        if not src["has_video"]:
            raise JobError("corrupt_input", "O ficheiro de origem não tem vídeo")

        last = {"t": 0.0, "v": -1}

        def on_progress(frac):
            pct = int(frac * 100)
            t = time.monotonic()
            if pct != last["v"] and (t - last["t"] >= PROGRESS_INTERVAL or pct >= 100):
                last.update(t=t, v=pct)
                send("progress", progress=min(pct, 99))

        send("progress", progress=0)
        ctx = {
            "progress": on_progress,
            "check": check,
            "mem_mb": int(p.get("memoryLimitMB") or DEFAULT_MEM_MB),
            "max_short_side": int(p.get("maxShortSide") or 0) or None,
            "work_dir": work,
        }
        result = operations.OPERATIONS[procedure](inp, out, p.get("op") or {}, src, ctx)
        if check.cancelled():
            raise JobError(CANCELLED, "Trabalho cancelado pelo utilizador")
        info = probe.video_info(out)
        send(
            "success",
            progress=100,
            output={"videoURI": out, "info": info},
            warnings=result.get("warnings", []),
            meta=result.get("meta", {}),
            processingTimeMs=int((time.monotonic() - started) * 1000),
        )
    except JobError as e:
        _safe_remove(p.get("outputVideoURI"))
        send("error", error={"code": e.code, "message": e.message},
             processingTimeMs=int((time.monotonic() - started) * 1000))
    except Exception as e:  # erro inesperado: nunca deixar o trabalho sem resposta
        traceback.print_exc()
        _safe_remove(p.get("outputVideoURI"))
        send("error", error={"code": PROCESSING_ERROR, "message": f"Erro inesperado: {e}"},
             processingTimeMs=int((time.monotonic() - started) * 1000))


def _safe_remove(path):
    try:
        if path and _inside_root(path) and os.path.exists(path):
            os.remove(path)
    except OSError:
        pass


def main():
    """Ligação ao RabbitMQ com um pedido de cada vez (prefetch=1) e ack só no fim.

    O processamento corre numa thread; a thread principal mantém a ligação viva
    (heartbeats) e publica as mensagens de progresso. Ao contrário do utilitário
    partilhado `utils/rabbit_mq.py`, uma tarefa longa não faz cair a ligação.
    """
    import pika

    params = pika.ConnectionParameters(
        host=os.getenv("RABBITMQ_HOST", "rabbitmq"),
        port=int(os.getenv("RABBITMQ_PORT", "5672")),
        credentials=pika.PlainCredentials(os.getenv("RABBITMQ_USER", "user"), os.getenv("RABBITMQ_PASS", "password")),
        heartbeat=60,
    )
    while True:
        try:
            conn = pika.BlockingConnection(params)
            ch = conn.channel()
            ch.exchange_declare(exchange=EXCHANGE, exchange_type="direct", durable=True)
            for q in (REQUEST_QUEUE, RESULTS_QUEUE):
                ch.queue_declare(queue=q, durable=True)
                ch.queue_bind(queue=q, exchange=EXCHANGE, routing_key=q)
            ch.basic_qos(prefetch_count=1)
            outbox = queue.Queue()

            def publish(msg):
                outbox.put(msg)

            def flush():
                while not outbox.empty():
                    msg = outbox.get()
                    ch.basic_publish(exchange=EXCHANGE, routing_key=RESULTS_QUEUE, body=json.dumps(msg),
                                     properties=pika.BasicProperties(delivery_mode=2))

            print(f"[video] à escuta em {REQUEST_QUEUE}", flush=True)
            for method, _props, body in ch.consume(REQUEST_QUEUE, inactivity_timeout=1):
                flush()
                if method is None:
                    continue
                try:
                    request = json.loads(body)
                except json.JSONDecodeError:
                    ch.basic_ack(method.delivery_tag)
                    continue
                print(f"[video] job={request.get('jobId')} {request.get('procedure')}", flush=True)
                worker = threading.Thread(target=process_job, args=(request, publish), daemon=True)
                worker.start()
                while worker.is_alive():
                    conn.process_data_events(time_limit=0.5)
                    flush()
                flush()
                ch.basic_ack(method.delivery_tag)
        except Exception as e:  # ligação perdida: tentar novamente
            print(f"[video] ligação ao RabbitMQ perdida: {e}; nova tentativa em 5 s", flush=True)
            time.sleep(5)


if __name__ == "__main__":
    main()
