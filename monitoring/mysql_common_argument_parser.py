import argparse
import getpass


class MysqlCommonArgumentParser(object):
    def __init__(self):
        self._parser = argparse.ArgumentParser()
        self._setup_common_args()

    def _setup_common_args(self):
        self._parser.add_argument('--mysql-host', required=True)
        self._parser.add_argument('--mysql-username', required=True)
        self._parser.add_argument('--mysql-password', required=False)
        self._parser.add_argument('--mysql-database', required=True)

    def add_argument(self, *args, **kwargs):
        self._parser.add_argument(*args, **kwargs)

    def parse_args(self):
        args = self._parser.parse_args()
        if not args.mysql_password:
            prompt = 'Enter password (for MySQL user {}): '.format(args.mysql_username)
            args.mysql_password = getpass.getpass(prompt=prompt)
        return args
