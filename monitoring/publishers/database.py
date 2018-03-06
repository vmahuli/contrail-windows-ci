from sqlalchemy import BigInteger, ForeignKey, Column, DateTime, Integer, String
from sqlalchemy.orm import relationship
from sqlalchemy.ext.declarative import declarative_base


MonitoringBase = declarative_base()


class Build(MonitoringBase):
    __tablename__ = 'builds'

    id = Column(Integer, primary_key=True)
    job_name = Column(String(4096), nullable=False)
    build_id = Column(Integer, nullable=False)
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
        self.stages = [Stage(stage) for stage in build_stats.stages]

    def __repr__(self):
        return "<Build(id={}, name={}, build_id={})>".format(self.id, self.job_name, self.build_id)


class Stage(MonitoringBase):
    __tablename__ = 'stages'

    id = Column(Integer, primary_key=True)
    build_id = Column(Integer, ForeignKey('builds.id'), nullable=False)
    name = Column(String(4096), nullable=False)
    status = Column(String(4096), nullable=False)
    duration_millis = Column(BigInteger, nullable=False)

    build = relationship('Build', back_populates='stages')

    def __init__(self, stage_stats):
        self.name = stage_stats.name
        self.status = stage_stats.status
        self.duration_millis = stage_stats.duration_millis

    def __repr__(self):
        return "<Stage(id={}, build_id={}, name={})>".format(self.id, self.build.build_id, self.name)


Build.stages = relationship('Stage', order_by=Stage.id, back_populates='build')
