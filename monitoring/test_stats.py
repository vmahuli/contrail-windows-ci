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

    def test_get_job_stats_returns_no_stages_with_no_stages(self):
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
            })

            build = get_build_stats(job_name='MyJob', build_url='http://localhost:8080/job/MyJob/1')

            self.assertIsNotNone(build)
            self.assertEqual(len(build.stages), 0)

    def test_get_job_stats_returns_no_stages_with_empty_stages(self):
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
                'stages': [],
            })

            build = get_build_stats(job_name='MyJob', build_url='http://localhost:8080/job/MyJob/1')

            self.assertIsNotNone(build)
            self.assertEqual(len(build.stages), 0)

    def test_get_job_stats_returns_stages_with_everything_set(self):
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': self.finished_at_millis,
                'stages': [
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
                ],
            })

            build = get_build_stats(job_name='MyJob', build_url='http://localhost:8080/job/MyJob/1')

            self.assertIsNotNone(build)
            self.assertEqual(len(build.stages), 2)
            self.assertIsNotNone(build.stages[0])
            self.assertIsNotNone(build.stages[1])

            self.assertEqual(build.stages[0].name, 'Preparation')
            self.assertEqual(build.stages[0].status, 'SUCCESS')
            self.assertEqual(build.stages[0].duration_millis, 1234)
            self.assertEqual(build.stages[0].build_id, build.id)
            self.assertEqual(build.stages[0].build, build)

            self.assertEqual(build.stages[1].name, 'Build')
            self.assertEqual(build.stages[1].status, 'FAILED')
            self.assertEqual(build.stages[1].duration_millis, 4321)
            self.assertEqual(build.stages[1].build_id, build.id)
            self.assertEqual(build.stages[1].build, build)


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

    def test_collect_and_push_build_stages(self):
        build_url = 'http://localhost:8080/job/MyJob/1'
        with requests_mock.mock() as m:
            m.get('http://localhost:8080/job/MyJob/1/wfapi/describe', json={
                'id': 1,
                'status': 'SUCCESS',
                'durationMillis': 1000,
                'endTimeMillis': 12345678,
                'stages': [
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
                ],
            })

            collect_and_push_build_stats(job_name='MyJob', build_url=build_url, db_session=self.session)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)
        build = self.session.query(Build).one()
        self.assertEqual(len(build.stages), 2)
        self.assertIsNotNone(build.stages[0])
        self.assertIsNotNone(build.stages[1])

        self.assertEqual(build.stages[0].name, 'Preparation')
        self.assertEqual(build.stages[0].status, 'SUCCESS')
        self.assertEqual(build.stages[0].duration_millis, 1234)
        self.assertEqual(build.stages[0].build_id, build.id)
        self.assertEqual(build.stages[0].build, build)

        self.assertEqual(build.stages[1].name, 'Build')
        self.assertEqual(build.stages[1].status, 'FAILED')
        self.assertEqual(build.stages[1].duration_millis, 4321)
        self.assertEqual(build.stages[1].build_id, build.id)
        self.assertEqual(build.stages[1].build, build)


class TestObjectStringifying(unittest.TestCase):
    def test_build_stringifying(self):
        build = Build(job_name='Test',
                  build_id=1234,
                  build_url='test',
                  finished_at_secs=5678,
                  status='SUCCESS',
                  duration_millis=4321)

        self.assertEqual(str(build), '<Build(id=None, name=Test, build_id=1234)>')

    def test_stage_stringifying(self):
        build = Build(job_name='Test',
                  build_id=1234,
                  build_url='test',
                  finished_at_secs=5678,
                  status='SUCCESS',
                  duration_millis=4321)

        stage = Stage(name='TestStage',
                      status='SUCCESS',
                      duration_millis=1010)

        build.stages.append(stage)

        self.assertEqual(str(stage), '<Stage(id=None, build_id=1234, name=TestStage)>')


if __name__ == '__main__':
    unittest.main()
