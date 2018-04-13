class BuildStatsMissingError(Exception):
    pass


class BuildStatsCollector(object):
    def __init__(self, build_stats_collector, test_stats_collector):
        self.build_stats_collector = build_stats_collector
        self.test_stats_collector = test_stats_collector

    def collect(self):
        build_stats = self.build_stats_collector.collect()

        try:
            build_stats.test_stats = self.test_stats_collector.collect()
        except:
            build_stats.test_stats = None

        return build_stats
