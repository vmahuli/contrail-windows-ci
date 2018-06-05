from collections import namedtuple


class BuildStats(object):
    def __init__(self, job_name, build_id, build_url, finished_at_secs, status, duration_millis,
                 stages, test_stats):
        self.job_name = job_name
        self.build_id = build_id
        self.build_url = build_url
        self.finished_at_secs = finished_at_secs
        self.status = status
        self.duration_millis = duration_millis
        self.stages = stages
        self.test_stats = test_stats


StageStats = namedtuple('StageStats', [
    'name',
    'status',
    'duration_millis'
])


TestStats = namedtuple('TestStats', [
    'total',
    'passed',
    'errors',
    'failures',
    'not_run',
    'inconclusive',
    'ignored',
    'skipped',
    'invalid',
    'report_url'
])
