import time


class MaxRetriesExceededError(Exception):
    pass


class FinishedBuildStatsPublisher(object):

    def __init__(self, collector, publisher):
        self.collector = collector
        self.publisher = publisher

    def collect_and_publish(self, delay_ms=1000, max_retries=10):
        while max_retries != 0:
            stats = self.collector.collect()
            if stats.is_build_finished():
                self.publisher.publish(stats)
                return

            time.sleep(delay_ms / 1000.0)
            max_retries -= 1

        raise MaxRetriesExceededError()
