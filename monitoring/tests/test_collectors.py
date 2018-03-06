#!/usr/bin/env python3
import unittest
import requests_mock
from datetime import datetime, timezone
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter, InvalidResponseCodeError
from stats import BuildStats, StageStats


class TestJenkinsCollect(unittest.TestCase):
    def setUp(self):
        self.finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        self.finished_at_millis = int(self.finished_at.timestamp() * 1000)
        self.default_build_url = 'http://1.2.3.4:5678/job/MyJob/1'
        self.default_api_url = 'http://1.2.3.4:5678/job/MyJob/1/wfapi/describe'
        self.default_collector = JenkinsCollectorAdapter('MyJob', self.default_build_url)

        self.default_build_stats_response = {
            'id': 1,
            'status': 'SUCCESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
        }

        self.default_stages_stats_response = [
            {
                'name': 'Preparation',
                'status': 'SUCCESS',
                'durationMillis': 1234,
            },
            {
                'name': 'Build',
                'status': 'FAILED',
                'durationMillis': 4321,
            },
        ]

    def assert_build_stats_is_valid(self, build_stats, json):
        self.assertIsNotNone(build_stats)
        self.assertIsInstance(build_stats, BuildStats)
        self.assertEqual(build_stats.job_name, 'MyJob')
        self.assertEqual(build_stats.build_id, json['id'])
        self.assertEqual(build_stats.build_url, self.default_build_url)
        self.assertEqual(build_stats.finished_at_secs, int(self.finished_at.timestamp()))
        self.assertEqual(build_stats.status, json['status'])
        self.assertEqual(build_stats.duration_millis, json['durationMillis'])

    def assert_stage_stats_is_valid(self, stage_stats, json):
        self.assertIsNotNone(stage_stats)
        self.assertIsInstance(stage_stats, StageStats)
        self.assertEqual(stage_stats.name, json['name'])
        self.assertEqual(stage_stats.status, json['status'])
        self.assertEqual(stage_stats.duration_millis, json['durationMillis'])

    def test_build_stats(self):
        with requests_mock.mock() as m:
            response = self.default_build_stats_response
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()
            self.assert_build_stats_is_valid(build_stats, response)

    def test_invalid_url(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/-1/wfapi/describe', status_code=404)

            collector = JenkinsCollectorAdapter('MyJob', 'http://1.2.3.4:5678/job/MyJob/-1')

            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_no_stages(self):
        with requests_mock.mock() as m:
            m.get(self.default_api_url, json=self.default_build_stats_response)
            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_empty_stages(self):
        with requests_mock.mock() as m:
            response = {**self.default_build_stats_response, **{ 'stages': [] }}
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_stages_stats(self):
        with requests_mock.mock() as m:
            response = {
                **self.default_build_stats_response,
                **{ 'stages': self.default_stages_stats_response }
            }
            m.get(self.default_api_url, json=response)
            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 2)

            self.assert_stage_stats_is_valid(build_stats.stages[0], self.default_stages_stats_response[0])
            self.assert_stage_stats_is_valid(build_stats.stages[1], self.default_stages_stats_response[1])


if __name__ == '__main__':
    unittest.main()
