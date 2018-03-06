from stats import BuildStats, StageStats


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


def get_test_build_stats_with_status(status, stages_stats=[]):
    return BuildStats(
        job_name = 'MyJob',
        build_id = 7,
        build_url = 'http://1.2.3.4:5678/job/MyJob/1',
        finished_at_secs = 2,
        status = status,
        duration_millis = 3,
        stages = stages_stats,
    )


def get_test_build_stats(stages_stats=[]):
    return get_test_build_stats_with_status('SUCCESS', stages_stats)


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
