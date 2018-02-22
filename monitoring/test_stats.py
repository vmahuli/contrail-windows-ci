#!/usr/bin/env python3
import unittest
import requests_mock
from datetime import datetime, timedelta, timezone
from unittest import mock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from database import MonitoringBase, Build
from stats import *


class TestGetBuildStatsEndpoint(unittest.TestCase):
    def test_build_stats_endpoint_is_good(self):
        url = get_build_stats_endpoint(build_url='http://localhost:8080/job/MyJob/1')
        self.assertEqual(url, 'http://localhost:8080/job/MyJob/1/wfapi/describe')


class TestGetJobStats(unittest.TestCase):
    def setUp(self):
        self.finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        self.finished_at_millis = int(self.finished_at.timestamp() * 1000)

    def test_get_job_stats_returns_job_with_everything_set(self):
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
            })

            build = get_build_stats(job_name='MyJob', build_url='http://localhost:8080/job/MyJob/1')
            self.assertIsNotNone(build)
            self.assertIsInstance(build, Build)
            self.assertEqual(build.job_name, 'MyJob')
            self.assertEqual(build.build_id, 1)
            self.assertEqual(build.build_url, 'http://localhost:8080/job/MyJob/1')
            self.assertEqual(build.finished_at_secs, int(self.finished_at.timestamp()))
            self.assertEqual(build.status, 'SUCCESS')
            self.assertEqual(build.duration_millis, 1000)

    def test_get_job_stats_returns_none_for_wrong_id(self):
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/-1/wfapi/describe', status_code=404)

            job = get_build_stats(job_name='MyJob', build_url='http://localhost:8080/job/MyJob/-1')
            self.assertIsNone(job)

    def test_get_job_stats_returns_job_with_failure(self):
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'FAILURE',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
            })

            job = get_build_stats(job_name='MyJob', build_url='http://localhost:8080/job/MyJob/1')
            self.assertEqual(job.status, 'FAILURE')


class TestCollectAndPushBuildStats(unittest.TestCase):
    def setUp(self):
        # Provision the SQLite in-memory database with our schema
        self.engine = create_engine('sqlite://')
        MonitoringBase.metadata.create_all(self.engine)

        self.session_factory = sessionmaker()
        self.session_factory.configure(bind=self.engine)
        self.session = self.session_factory()

    def tearDown(self):
        self.session = None
        self.session_factory = None
        self.engine.dispose()
        self.engine = None

    def test_collect_and_push_build_stats(self):
        build_url = 'http://localhost:8080/job/MyJob/1'
        finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        finished_at_millis = int(finished_at.timestamp() * 1000)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 0)

        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': finished_at_millis,
            })

            collect_and_push_build_stats(job_name='MyJob', build_url=build_url, db_session=self.session)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)
        build = self.session.query(Build).one()
        self.assertEqual(build.job_name, 'MyJob')
        self.assertEqual(build.build_id, 1)
        self.assertEqual(build.build_url, 'http://localhost:8080/job/MyJob/1')
        self.assertEqual(build.finished_at_secs, int(finished_at.timestamp()))
        self.assertEqual(build.status, 'SUCCESS')
        self.assertEqual(build.duration_millis, 1000)


if __name__ == '__main__':
    unittest.main()
