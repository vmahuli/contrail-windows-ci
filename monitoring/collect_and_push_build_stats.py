#!/usr/bin/env python3
from common import get_mysql_connection_string, MysqlCommonArgumentParser
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from stats import collect_and_push_build_stats


def parse_args():
    parser = MysqlCommonArgumentParser()
    parser.add_argument('--job-name', required=True)
    parser.add_argument('--build-url', required=True)
    return parser.parse_args()


def main():
    args = parse_args()

    conn_string = get_mysql_connection_string(host=args.mysql_host, username=args.mysql_username,
                                              password=args.mysql_password,
                                              database=args.mysql_database)
    engine = create_engine(conn_string)
    session_factory = sessionmaker()
    session_factory.configure(bind=engine)
    session = session_factory()

    collect_and_push_build_stats(job_name=args.job_name, build_url=args.build_url, db_session=session)


if __name__ == '__main__':
    main()
