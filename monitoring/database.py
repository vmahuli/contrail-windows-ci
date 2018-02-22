from sqlalchemy import BigInteger, ForeignKey, Column, DateTime, Integer, String
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

    def __repr__(self):
        return "<Build(id={}, name={}, build_id={})>".format(self.id, self.build_id, self.job_name)
