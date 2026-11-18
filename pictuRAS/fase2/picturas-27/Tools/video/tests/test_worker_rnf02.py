"""RNF-02 regression tests for the RabbitMQ side of the video worker.

A fake `pika` stands in for the broker, so the tests check what the worker
does with messages (thread, ack at the end, replies, stop on SIGTERM)
without RabbitMQ. Plain unittest, so it also runs under pytest.

Written with AI assistance (Claude) and reviewed by the group (PL3-G7).
"""
import importlib
import json
import os
import sys
import threading
import time
import types
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
# Tools/ (for utils/, as copied into the image) goes last: it also has a video/ dir
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))


class FakeChannel:
    def __init__(self):
        self.acks, self.published, self.consuming = [], [], False
        self.stopped = threading.Event()

    def exchange_declare(self, **_): pass
    def queue_declare(self, **_): pass
    def queue_bind(self, **_): pass
    def basic_qos(self, **_): pass

    def basic_publish(self, exchange, routing_key, body):
        self.published.append((routing_key, json.loads(body)))

    def basic_ack(self, delivery_tag):
        self.acks.append(delivery_tag)

    def basic_consume(self, queue, on_message_callback, auto_ack):
        self.queue = queue

    def start_consuming(self):
        self.stopped.wait(5)

    def stop_consuming(self):
        self.stopped.set()


class FakeConnection:
    def __init__(self, params):
        self.params, self.chan, self.closed = params, FakeChannel(), False

    def channel(self):
        return self.chan

    def add_callback_threadsafe(self, fn):
        fn()  # the real pika runs it on the connection thread

    def close(self):
        self.closed = True


def install_fakes():
    pika = types.ModuleType("pika")
    pika.PlainCredentials = lambda *a: None
    pika.ConnectionParameters = lambda *a, **k: k
    pika.BlockingConnection = FakeConnection
    pika.exceptions = types.SimpleNamespace(AMQPConnectionError=Exception)
    et = types.ModuleType("pika.exchange_type")
    et.ExchangeType = types.SimpleNamespace(direct="direct")
    sys.modules.update({"pika": pika, "pika.exchange_type": et})
    try:
        import pytz  # noqa: F401
    except ImportError:
        import datetime
        sys.modules["pytz"] = types.SimpleNamespace(utc=datetime.timezone.utc)
    try:
        import dotenv  # noqa: F401
    except ImportError:
        sys.modules["dotenv"] = types.SimpleNamespace(load_dotenv=lambda *a, **k: None)


def message(preview=False):
    return json.dumps({"messageId": "m1", "procedure": "video", "parameters": {
        "inputImageURI": "in.mp4", "outputImageURI": "out.mp4", "tools": [],
        "preview": preview, "progress": {}}}).encode()


class WorkerRNF02(unittest.TestCase):
    def setUp(self):
        install_fakes()
        os.environ["VIDEO_QUEUE"] = "video_preview_queue"
        self.video = importlib.reload(importlib.import_module("video"))

    def tearDown(self):
        os.environ.pop("VIDEO_QUEUE", None)

    def wait_for(self, cond):
        for _ in range(200):
            if cond():
                return
            time.sleep(0.01)
        self.fail("condition not reached")

    def test_queue_comes_from_the_environment(self):
        w = self.video.VideoWorker()
        w._channel.stopped.set()
        with self.assertRaises(SystemExit):
            w.run()
        self.assertEqual(w._channel.queue, "video_preview_queue")

    def test_heartbeat_is_enabled(self):
        w = self.video.VideoWorker()
        self.assertGreater(w._connection.params["heartbeat"], 0)

    def test_job_runs_in_a_thread_and_is_acked_only_at_the_end(self):
        release = threading.Event()

        def slow_process(*a, **k):
            release.wait(2)
            return {"frames": 1}

        self.video.process_video = slow_process
        w = self.video.VideoWorker()
        method = types.SimpleNamespace(delivery_tag=7)
        w.callback(w._channel, method, None, message())
        # the callback returned at once (the connection thread is free)…
        self.assertTrue(w._busy.is_set())
        self.assertEqual(w._channel.acks, [])
        release.set()
        # …and the ack and the reply come when the job ends
        self.wait_for(lambda: w._channel.acks == [7])
        replies = [m for q, m in w._channel.published if q == "project_queue"]
        self.assertEqual(replies[0]["status"], "success")
        self.assertFalse(w._busy.is_set())

    def test_a_failed_job_is_reported_and_acked(self):
        def boom(*a, **k):
            raise RuntimeError("ffmpeg failed")

        self.video.process_video = boom
        w = self.video.VideoWorker()
        w.callback(w._channel, types.SimpleNamespace(delivery_tag=3), None, message())
        self.wait_for(lambda: w._channel.acks == [3])
        replies = [m for q, m in w._channel.published if q == "project_queue"]
        self.assertEqual(replies[0]["status"], "error")

    def test_sigterm_stops_consuming_and_leaves_the_job_unacked(self):
        release = threading.Event()
        self.video.process_video = lambda *a, **k: (release.wait(2), {"frames": 1})[1]
        w = self.video.VideoWorker()
        w.callback(w._channel, types.SimpleNamespace(delivery_tag=9), None, message())
        w._on_sigterm()
        self.assertTrue(w._channel.stopped.is_set())
        with self.assertRaises(SystemExit):
            w.run()
        # closed without the ack: RabbitMQ gives the job to another replica
        self.assertTrue(w._connection.closed)
        self.assertEqual(w._channel.acks, [])
        # and no new job is taken while stopping
        w.callback(w._channel, types.SimpleNamespace(delivery_tag=10), None, message())
        release.set()


if __name__ == "__main__":
    unittest.main()
