"""Unit tests for the RNF-02 scaling rule (python -m unittest, or pytest)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))
from scaling_rule import Config, desired_replicas  # noqa: E402

CFG = Config(min_replicas=1, max_replicas=4, scale_in_delay_s=60)


class ScalingRule(unittest.TestCase):
    def test_idle_queue_keeps_the_minimum(self):
        self.assertEqual(desired_replicas(0, 0, 1, None, 100, CFG)[0], 1)

    def test_waiting_jobs_add_one_replica_per_job(self):
        self.assertEqual(desired_replicas(2, 1, 1, None, 100, CFG)[0], 3)

    def test_never_more_than_the_maximum(self):
        self.assertEqual(desired_replicas(20, 1, 1, None, 100, CFG)[0], 4)

    def test_running_jobs_alone_do_not_scale_out(self):
        # nothing waiting: the replicas running them are enough
        self.assertEqual(desired_replicas(0, 3, 3, None, 100, CFG)[0], 3)

    def test_busy_replicas_are_never_removed(self):
        # one job still running, queue otherwise empty: keep all 4
        self.assertEqual(desired_replicas(0, 1, 4, None, 1000, CFG)[0], 4)

    def test_scale_in_only_after_the_idle_delay(self):
        target, idle = desired_replicas(0, 0, 4, None, 100, CFG)
        self.assertEqual((target, idle), (4, 100))
        self.assertEqual(desired_replicas(0, 0, 4, idle, 159, CFG)[0], 4)
        self.assertEqual(desired_replicas(0, 0, 4, idle, 160, CFG)[0], 1)

    def test_new_work_resets_the_idle_timer(self):
        _, idle = desired_replicas(0, 0, 4, 100, 150, CFG)
        _, idle = desired_replicas(1, 0, 4, idle, 155, CFG)
        self.assertIsNone(idle)

    def test_restores_the_minimum_if_a_replica_died(self):
        self.assertEqual(desired_replicas(0, 0, 0, None, 100, CFG)[0], 1)


if __name__ == "__main__":
    unittest.main()
