#!/usr/bin/env python3
from common import get_mysql_connection_string, MysqlCommonArgumentParser
from sqlalchemy import create_engine
from database import MonitoringBase


def parse_args():
    parser = MysqlCommonArgumentParser()
    return parser.parse_args()


def provision_database(connection_string, model):
    engine = create_engine(connection_string, echo=True)
    model.metadata.create_all(engine)


def main():
    args = parse_args()
    connection_string = get_mysql_connection_string(host=args.mysql_host,
                                                    username=args.mysql_username,
                                                    password=args.mysql_password,
                                                    database=args.mysql_database)
    provision_database(connection_string, model=MonitoringBase)


if __name__ == '__main__':
    main()
