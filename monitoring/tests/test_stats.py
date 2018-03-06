import unittest
from tests.common import get_test_build_stats_with_status


class TestIsFinished(unittest.TestCase):
    def test_in_progress(self):
        build_status = get_test_build_stats_with_status('IN_PROGRESS')
        self.assertFalse(build_status.is_build_finished())

    def test_success(self):
        build_status = get_test_build_stats_with_status('SUCCESS')
        self.assertTrue(build_status.is_build_finished())

    def test_failed(self):
        build_status = get_test_build_stats_with_status('FAILED')
        self.assertTrue(build_status.is_build_finished())
