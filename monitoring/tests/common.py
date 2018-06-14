from stats import BuildStats, StageStats, TestStats


TEST_STAGE1_STATS = StageStats(
    name = 'Stage1',
    status = 'OK',
    duration_millis = 123,
)

TEST_STAGE2_STATS = StageStats(
    name = 'Stage2',
    status = 'FAILED',
    duration_millis = 321,
)

EXAMPLE_TESTS_STATS = TestStats(
    total = 3,
    passed = 2,
    errors = 1,
    failures = 0,
    not_run = 0,
    inconclusive = 0,
    ignored = 0,
    skipped = 0,
    invalid = 0,
    report_url = 'http://1.2.3.4/build/1/report.html',
)


def get_test_build_stats(stages_stats=[], test_stats=None):
        return BuildStats(
        job_name = 'MyJob',
        build_id = 7,
        build_url = 'http://1.2.3.4:5678/job/MyJob/1',
        finished_at_secs = 2,
        status = 'SUCCESS',
        duration_millis = 3,
        stages = stages_stats,
        test_stats = test_stats,
    )


def assert_stage_matches_stage_stats(test_case, stage, stage_stats):
    test_case.assertIsNotNone(stage)
    test_case.assertEqual(stage.name, stage_stats.name)
    test_case.assertEqual(stage.status, stage_stats.status)
    test_case.assertEqual(stage.duration_millis, stage_stats.duration_millis)


def assert_build_matches_build_stats(test_case, build, build_stats):
    test_case.assertIsNotNone(build)
    test_case.assertEqual(build.job_name, build_stats.job_name)
    test_case.assertEqual(build.build_id, build_stats.build_id)
    test_case.assertEqual(build.build_url, build_stats.build_url)
    test_case.assertEqual(build.finished_at_secs, build_stats.finished_at_secs)
    test_case.assertEqual(build.status, build_stats.status)
    test_case.assertEqual(build.duration_millis, build_stats.duration_millis)


def assert_report_matches_test_stats(test_case, report, test_stats):
    test_case.assertIsNotNone(report)
    test_case.assertEqual(report.total, test_stats.total)
    test_case.assertEqual(report.passed, test_stats.passed)
    test_case.assertEqual(report.errors, test_stats.errors)
    test_case.assertEqual(report.failures, test_stats.failures)
    test_case.assertEqual(report.not_run, test_stats.not_run)
    test_case.assertEqual(report.inconclusive, test_stats.inconclusive)
    test_case.assertEqual(report.ignored, test_stats.ignored)
    test_case.assertEqual(report.skipped, test_stats.skipped)
    test_case.assertEqual(report.invalid, test_stats.invalid)
    test_case.assertEqual(report.report_url, test_stats.report_url)


def assert_test_stats_equal(test_case, stats, expected):
    test_case.assertIsNotNone(stats)
    test_case.assertEqual(stats.total, expected.total)
    test_case.assertEqual(stats.passed, expected.passed)
    test_case.assertEqual(stats.errors, expected.errors)
    test_case.assertEqual(stats.failures, expected.failures)
    test_case.assertEqual(stats.not_run, expected.not_run)
    test_case.assertEqual(stats.inconclusive, expected.inconclusive)
    test_case.assertEqual(stats.ignored, expected.ignored)
    test_case.assertEqual(stats.skipped, expected.skipped)
    test_case.assertEqual(stats.invalid, expected.invalid)
    test_case.assertEqual(stats.report_url, expected.report_url)
