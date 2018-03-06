from publishers.database import Build


class DatabasePublisherAdapter(object):

    def __init__(self, database_session):
        self.session = database_session.get_database_session()


    def publish(self, build_stats):
        build = Build(build_stats)
        self.session.add(build)
        self.session.commit()
