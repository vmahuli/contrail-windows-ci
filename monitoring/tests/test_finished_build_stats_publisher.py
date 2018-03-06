#!/usr/bin/env python3
import unittest
import timeout_decorator
from unittest.mock import MagicMock
from finished_build_stats_publisher import FinishedBuildStatsPublisher, MaxRetriesExceededError
from tests.common import get_test_build_stats_with_status


class TestFinishedBuildStatsPublisher(unittest.TestCase):
    def setUp(self):
        self.collector = MagicMock()
        self.publisher = MagicMock()
        self.publisher.publish = MagicMock()
        self.stats_publisher = FinishedBuildStatsPublisher(self.collector, self.publisher)
        self.build_stats_success = get_test_build_stats_with_status('SUCCESS')
        self.build_stats_in_progress = get_test_build_stats_with_status('IN_PROGRESS')

    def test_collecting_already_finished_build(self):
        self.collector.collect = MagicMock(return_value=self.build_stats_success)

        self.stats_publisher.collect_and_publish()

        self.collector.collect.assert_called_once_with()
        self.publisher.publish.assert_called_once_with(self.build_stats_success)

    def test_collecting_in_progress_build_with_retries(self):
        def counter():
            yield self.build_stats_in_progress
            yield self.build_stats_in_progress
            while True:
                yield self.build_stats_success

        self.collector.collect = MagicMock(side_effect=counter())

        self.stats_publisher.collect_and_publish(delay_ms=0)

        self.assertEqual(self.collector.collect.call_count, 3)
        self.publisher.publish.assert_called_once_with(self.build_stats_success)

    @timeout_decorator.timeout(2)
    def test_collecting_in_progress_build_with_timeout(self):
        self.collector.collect = MagicMock(return_value=self.build_stats_in_progress)

        with self.assertRaises(MaxRetriesExceededError):
            self.stats_publisher.collect_and_publish(delay_ms=0, max_retries=10)

        self.assertEqual(self.collector.collect.call_count, 10)
        self.publisher.publish.assert_not_called()


if __name__ == '__main__':
    unittest.main()
