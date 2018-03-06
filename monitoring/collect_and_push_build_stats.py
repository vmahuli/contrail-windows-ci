#!/usr/bin/env python3
from mysql_common_argument_parser import MysqlCommonArgumentParser
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter
from publishers.database_publisher_adapter import DatabasePublisherAdapter
from publishers.mysql_session import MySQLSession
from finished_build_stats_publisher import FinishedBuildStatsPublisher


def parse_args():
    parser = MysqlCommonArgumentParser()
    parser.add_argument('--job-name', required=True)
    parser.add_argument('--build-url', required=True)
    return parser.parse_args()


def main():
    args = parse_args()

    collector = JenkinsCollectorAdapter(job_name=args.job_name, build_url=args.build_url)
    db_session = MySQLSession(host=args.mysql_host, username=args.mysql_username,
                              password=args.mysql_password, database=args.mysql_database)
    publisher = DatabasePublisherAdapter(database_session=db_session)

    stats_publisher = FinishedBuildStatsPublisher(collector, publisher)
    stats_publisher.collect_and_publish()


if __name__ == '__main__':
    main()
