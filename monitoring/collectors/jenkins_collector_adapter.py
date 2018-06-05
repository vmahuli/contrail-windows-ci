import requests
from collectors.exceptions import InvalidResponseCodeError
from stats import BuildStats, StageStats


class JenkinsCollectorAdapter(object):

    def __init__(self, job_name, job_status, build_url):
        self.job_name = job_name
        self.job_status = job_status
        self.url = build_url


    def collect(self):
        resp = self._get_raw_stats_from_jenkins()
        return self._convert_raw_stats_to_build_stats(resp)


    def _get_raw_stats_from_jenkins(self):
        endpoint = self._get_build_stats_endpoint(self.url)
        resp = requests.get(endpoint)

        if resp.status_code != 200:
            raise InvalidResponseCodeError()

        return resp.json()


    def _convert_raw_stats_to_build_stats(self, raw_stats):
        timestamp = int(raw_stats['endTimeMillis'] / 1000)

        stages_stats = []

        if 'stages' in raw_stats.keys():
            stages_stats = [self._get_stage_stats(x) for x in raw_stats['stages']]

        build_stats = BuildStats(
            job_name = self.job_name,
            build_url = self.url,
            build_id = raw_stats['id'],
            finished_at_secs = timestamp,
            status = self.job_status,
            duration_millis = raw_stats['durationMillis'],
            stages = stages_stats,
            test_stats = []
        )

        return build_stats


    def _get_stage_stats(self, raw_stage_stats):
        stage_name = raw_stage_stats['name']
        stage_status = raw_stage_stats['status']
        stage_duration = raw_stage_stats['durationMillis']

        stage_status = self._apply_in_progress_post_actions_override(stage_name, stage_status)

        return StageStats(
            name = stage_name,
            status = stage_status,
            duration_millis = stage_duration
        ) 


    def _apply_in_progress_post_actions_override(self, name, status):
        # Jenkins Collector should be invoked as the last thing in the last stage of a Jenkinsfile
        # in the 'post actions' stage. However, Jenkins will report that at the time of the
        # invocation, the 'post action' stage has status 'IN PROGRESS'.
        # We assume that:
        # 1) If we reached this point, current 'post action' stage is pretty much successful.
        # 2) If Jenkins Collector fails, then nothing will be pushed to the monitoring database
        #    anyways. No incorrect stage results are pushed (e.g. no 'SUCCESS' will be pushed).
        # For this reason, we overwrite the 'IN PROGRESS' status of current stage to 'SUCCESS', so
        # that anyone analyzing monitoring database entries won't get confused by a bunch of
        # 'IN PROGRESS'-es in post stage.
        if name == "Declarative: Post Actions" and status == 'IN PROGRESS':
            return 'SUCCESS'
        else: 
            return status


    @classmethod
    def _get_build_stats_endpoint(cls, build_url):
        return '{}/wfapi/describe'.format(build_url)
