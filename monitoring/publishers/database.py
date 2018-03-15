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


Build.stages = relationship('Stage', back_populates='build')
