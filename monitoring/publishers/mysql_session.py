from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker


class MySQLSession(object):
    def __init__(self, host, username, password, database, echo=False):
        connection_string = self._get_connection_string(host, username, password, database)
        self.engine = create_engine(connection_string, echo=echo)

    def get_database_session(self):
        engine = self.get_database_engine()
        session_factory = sessionmaker()
        session_factory.configure(bind=engine)
        return session_factory()

    def get_database_engine(self):
        return self.engine

    def _get_connection_string(self, host, username, password, database):
        return 'mysql://{}:{}@{}/{}'.format(username, password, host, database)
