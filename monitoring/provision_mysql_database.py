#!/usr/bin/env python3
from sqlalchemy import create_engine
from publishers.database import MonitoringBase
from publishers.mysql_session import MySQLSession
from mysql_common_argument_parser import MysqlCommonArgumentParser


def parse_args():
    parser = MysqlCommonArgumentParser()
    return parser.parse_args()


def provision_database(database_session, model):
    engine = database_session.get_database_engine()
    model.metadata.create_all(engine)


def main():
    args = parse_args()

    db_session = MySQLSession(host=args.mysql_host, username=args.mysql_username,
                              password=args.mysql_password, database=args.mysql_database, echo=True)
    provision_database(db_session, MonitoringBase)


if __name__ == '__main__':
    main()
