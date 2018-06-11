#!/usr/bin/env python3
from mysql_common_argument_parser import MysqlCommonArgumentParser
from collectors.build_stats_collector import BuildStatsCollector
from collectors.null_collector import NullCollector
from collectors.xml_report_collector import XmlReportCollector
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter
from publishers.database_publisher_adapter import DatabasePublisherAdapter
from publishers.mysql_session import MySQLSession


def parse_args():
    parser = MysqlCommonArgumentParser()
    parser.add_argument('--job-name', required=True)
    parser.add_argument('--job-status', required=True)
    parser.add_argument('--build-url', required=True)
    parser.add_argument('--reports-json-url', required=False)
    return parser.parse_args()


def get_test_stats_collector(args):
    if args.reports_json_url:
        return XmlReportCollector(url=args.reports_json_url)
    else:
        return NullCollector()


def main():
    args = parse_args()

    build_stats_collector = JenkinsCollectorAdapter(job_name=args.job_name,
        job_status=args.job_status, build_url=args.build_url)
    test_stats_collector = get_test_stats_collector(args)
    collector = BuildStatsCollector(build_stats_collector, test_stats_collector)

    db_session = MySQLSession(host=args.mysql_host, username=args.mysql_username,
                              password=args.mysql_password, database=args.mysql_database)
    publisher = DatabasePublisherAdapter(database_session=db_session)

    stats = collector.collect()
    publisher.publish(stats)


if __name__ == '__main__':
    main()
