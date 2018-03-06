from collections import namedtuple


BuildStats = namedtuple('BuildStats', [
    'job_name',
    'build_id',
    'build_url',
    'finished_at_secs',
    'status',
    'duration_millis',
    'stages'
])

BuildStats.is_build_finished = lambda self: self.status != 'IN_PROGRESS'


StageStats = namedtuple('StageStats', [
    'name',
    'status',
    'duration_millis'
])
