from sqlalchemy import BigInteger, ForeignKeyConstraint, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base


MonitoringBase = declarative_base()


class Build(MonitoringBase):
    __tablename__ = 'builds'

    job_name = Column(String(1024), primary_key=True)
    build_id = Column(Integer, primary_key=True)
    build_url = Column(String(4096), nullable=False)
    finished_at_secs = Column(BigInteger, nullable=False)
    status = Column(String(4096), nullable=False)
    duration_millis = Column(BigInteger, nullable=False)

    def __init__(self, build_stats):
        self.job_name = build_stats.job_name
        self.build_id = build_stats.build_id
        self.build_url = build_stats.build_url
        self.finished_at_secs = build_stats.finished_at_secs
        self.status = build_stats.status
        self.duration_millis = build_stats.duration_millis
        self.stages = [Stage(stage, build_id=self.build_id, job_name=self.job_name)
                       for stage in build_stats.stages]

        if build_stats.test_stats is not None:
            self.report = Report(build_stats.test_stats, job_name=self.job_name,
                                 build_id=self.build_id)

    def __repr__(self):
        return "<Build(job_name={}, build_id={})>".format(self.job_name, self.build_id)


class Stage(MonitoringBase):
    __tablename__ = 'stages'

    job_name = Column(String(1024), primary_key=True)
    build_id = Column(Integer, primary_key=True)
    name = Column(String(256), primary_key=True)
    status = Column(String(4096), nullable=False)
    duration_millis = Column(BigInteger, nullable=False)

    build = relationship('Build', back_populates='stages')

    __table_args__ = (
        ForeignKeyConstraint(['job_name', 'build_id'], ['builds.job_name', 'builds.build_id']),
    )

    def __init__(self, stage_stats, job_name=None, build_id=None):
        self.job_name = job_name
        self.build_id = build_id
        self.name = stage_stats.name
        self.status = stage_stats.status
        self.duration_millis = stage_stats.duration_millis

    def __repr__(self):
        return "<Stage(job_name={}, build_id={}, stage={})>".format(self.job_name, self.build_id, self.name)


class Report(MonitoringBase):
    __tablename__ = 'reports'

    job_name = Column(String(2048), primary_key=True)
    build_id = Column(Integer, primary_key=True)
    total = Column(Integer, nullable=False)
    passed = Column(Integer, nullable=False)
    errors = Column(Integer, nullable=False)
    failures = Column(Integer, nullable=False)
    not_run = Column(Integer, nullable=False)
    inconclusive = Column(Integer, nullable=False)
    ignored = Column(Integer, nullable=False)
    skipped = Column(Integer, nullable=False)
    invalid = Column(Integer, nullable=False)
    report_url = Column(String(4096), nullable=False)

    __table_args__ = (
        ForeignKeyConstraint(['job_name', 'build_id'], ['builds.job_name', 'builds.build_id']),
    )

    build = relationship('Build', back_populates='report')

    def __init__(self, test_stats, job_name=None, build_id=None):
        self.job_name = job_name
        self.build_id = build_id
        self.total = test_stats.total
        self.passed = test_stats.passed
        self.errors = test_stats.errors
        self.failures = test_stats.failures
        self.not_run = test_stats.not_run
        self.inconclusive = test_stats.inconclusive
        self.ignored = test_stats.ignored
        self.skipped = test_stats.skipped
        self.invalid = test_stats.invalid
        self.report_url = test_stats.report_url


Build.stages = relationship('Stage', back_populates='build')
Build.report = relationship('Report', back_populates='build', uselist=False)
