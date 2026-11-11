"""Exploratory: video_queue with 1 consumer (current) vs 2 consumers.
4 'full' jobs (20 s 720p re-encode, like the worker's libx264 veryfast) + 1 'preview' job (3 s) arriving last.
Reports makespan and how long the preview waits. Usage: python3 fila.py <consumers>"""
import subprocess, sys, time, json, threading, queue
C = int(sys.argv[1])
def job(kind, i):
    t = ["-t", "3"] if kind == "preview" else []
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-threads", "1", "-i", "clip20.mp4", *t, "-vf", "eq=brightness=0.1",
                    "-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-c:a", "copy", f"out_{kind}{i}.mp4"], check=True)
q = queue.Queue(); [q.put(("full", i)) for i in range(4)]; q.put(("preview", 0))
t0 = time.time(); res = []
def consumer():
    while True:
        try: kind, i = q.get_nowait()
        except queue.Empty: return
        s = time.time() - t0; job(kind, i); res.append({"job": f"{kind}{i}", "wait_s": round(s, 1), "done_s": round(time.time() - t0, 1)})
ts = [threading.Thread(target=consumer) for _ in range(C)]; [t.start() for t in ts]; [t.join() for t in ts]
print(json.dumps({"consumers": C, "makespan_s": round(time.time() - t0, 1), "jobs": res}))
