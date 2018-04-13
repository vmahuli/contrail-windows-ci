#!/usr/bin/env python3
import unittest
from unittest.mock import MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from publishers.database_publisher_adapter import DatabasePublisherAdapter
from publishers.database import Build, Stage, Report, MonitoringBase
from stats import BuildStats, StageStats
from tests.common import (get_test_build_stats, TEST_STAGE1_STATS, TEST_STAGE2_STATS,
                          EXAMPLE_TESTS_STATS)
from tests.common import (assert_stage_matches_stage_stats, assert_build_matches_build_stats,
                          assert_report_matches_test_stats)


class TestPublishing(unittest.TestCase):
    class InMemorySQLiteSession(object):
        def __init__(self):
            self.engine = create_engine('sqlite://')

        def get_database_session(self):
            engine = self.get_database_engine()
            session_factory = sessionmaker()
            session_factory.configure(bind=engine)
            return session_factory()

        def get_database_engine(self):
            return self.engine

    def setUp(self):
        db_session = TestPublishing.InMemorySQLiteSession()
        self.session = db_session.get_database_session()

        # Provision the SQLite in-memory database with our schema
        engine = db_session.get_database_engine()
        MonitoringBase.metadata.create_all(engine)

        self.publisher = DatabasePublisherAdapter(db_session)

    def test_publish_build_stats_no_stages(self):
        build_stats = get_test_build_stats()
        self.publisher.publish(build_stats)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)

        stage_count = self.session.query(Stage).count()
        self.assertEqual(stage_count, 0)

        build = self.session.query(Build).one()
        assert_build_matches_build_stats(self, build, build_stats)

    def test_publish_build_stats_with_stages(self):
        build_stats = get_test_build_stats([TEST_STAGE1_STATS, TEST_STAGE2_STATS])
        self.publisher.publish(build_stats)

        build_count = self.session.query(Build).count()
        self.assertEqual(build_count, 1)

        build = self.session.query(Build).one()
        self.assertEqual(len(build.stages), 2)

        assert_stage_matches_stage_stats(self, build.stages[0], TEST_STAGE1_STATS)
        self.assertEqual(build.stages[0].build_id, build.build_id)
        self.assertEqual(build.stages[0].build, build)

        assert_stage_matches_stage_stats(self, build.stages[1], TEST_STAGE2_STATS)
        self.assertEqual(build.stages[1].build_id, build.build_id)
        self.assertEqual(build.stages[1].build, build)

    def test_publish_build_stats_with_report(self):
        self.assertEqual(self.session.query(Build).count(), 0)
        self.assertEqual(self.session.query(Report).count(), 0)

        build_stats = get_test_build_stats(test_stats=EXAMPLE_TESTS_STATS)
        self.publisher.publish(build_stats)

        self.assertEqual(self.session.query(Build).count(), 1)
        self.assertEqual(self.session.query(Report).count(), 1)

        build = self.session.query(Build).one()
        assert_build_matches_build_stats(self, build, build_stats)
        assert_report_matches_test_stats(self, build.report, EXAMPLE_TESTS_STATS)


if __name__ == '__main__':
    unittest.main()
