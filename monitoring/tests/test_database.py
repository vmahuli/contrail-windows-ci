#!/usr/bin/env python3
import unittest
from collections import namedtuple
from stats import BuildStats, StageStats, TestStats
from publishers.database import Build, Stage, Report
from tests.common import (get_test_build_stats, TEST_STAGE1_STATS, TEST_STAGE2_STATS,
                          EXAMPLE_TESTS_STATS)
from tests.common import (assert_build_matches_build_stats, assert_stage_matches_stage_stats,
                          assert_report_matches_test_stats)


class TestObjectStringifying(unittest.TestCase):

    def test_build_stringifying(self):
        build = Build(get_test_build_stats())
        self.assertEqual(str(build), '<Build(job_name=MyJob, build_id=7)>')

    def test_stage_stringifying(self):
        build = Build(get_test_build_stats([TEST_STAGE1_STATS]))
        stage = build.stages[0]

        self.assertEqual(str(stage), '<Stage(job_name=MyJob, build_id=7, stage=Stage1)>')


class TestObjectConversions(unittest.TestCase):

    def test_stage_from_stage_stats(self):
        stage = Stage(TEST_STAGE1_STATS)

        assert_stage_matches_stage_stats(self, stage, TEST_STAGE1_STATS)
        self.assertEqual(stage.build_id, None)
        self.assertEqual(stage.build, None)

    def test_build_from_build_stats(self):
        build_stats = get_test_build_stats()
        build = Build(build_stats)

        assert_build_matches_build_stats(self, build, build_stats)
        self.assertIsNotNone(build.stages)
        self.assertEqual(len(build.stages), 0)

    def test_build_from_build_and_stages_stats(self):
        build_stats = get_test_build_stats([TEST_STAGE1_STATS, TEST_STAGE2_STATS])
        build = Build(build_stats)

        assert_build_matches_build_stats(self, build, build_stats)
        self.assertIsNotNone(build.stages)
        self.assertEqual(len(build.stages), 2)

        assert_stage_matches_stage_stats(self, build.stages[0], TEST_STAGE1_STATS)
        self.assertEqual(build.stages[0].build_id, build_stats.build_id)
        self.assertEqual(build.stages[0].build, build)

        assert_stage_matches_stage_stats(self, build.stages[1], TEST_STAGE2_STATS)
        self.assertEqual(build.stages[1].build_id, build_stats.build_id)
        self.assertEqual(build.stages[1].build, build)

    def test_report_from_test_stats(self):
        test_stats = TestStats(total=1, passed=1, errors=0, failures=0, not_run=0, inconclusive=0,
                               ignored=0, skipped=0, invalid=0,
                               report_url='http://1.2.3.4/build/1/report.html')
        report = Report(test_stats, job_name='MyJob', build_id=1)

        assert_report_matches_test_stats(self, report, test_stats)
        self.assertEqual(report.build_id, 1)
        self.assertEqual(report.job_name, 'MyJob')

    def test_build_from_build_and_test_stats(self):
        build_stats = get_test_build_stats(test_stats=EXAMPLE_TESTS_STATS)
        build = Build(build_stats)
        assert_build_matches_build_stats(self, build, build_stats)
        assert_report_matches_test_stats(self, build.report, EXAMPLE_TESTS_STATS)

    def test_build_from_build_and_without_test_stats(self):
        build_stats = get_test_build_stats(test_stats=None)
        build = Build(build_stats)
        assert_build_matches_build_stats(self, build, build_stats)
        self.assertIsNone(build.report)


if __name__ == '__main__':
    unittest.main()
