#!/usr/bin/env python3
import json
import unittest
import requests_mock
from datetime import datetime, timezone
from collectors.jenkins_collector_adapter import JenkinsCollectorAdapter, InvalidResponseCodeError
from collectors.xml_report_collector import XmlReportCollector, MissingXmlAttributeError, \
    InvalidJsonFormatError, EmptyXmlReportsListError
from stats import BuildStats, StageStats, TestStats
from xml.etree.ElementTree import ParseError
from json import JSONDecodeError
from tests.common import assert_test_stats_equal


class TestJenkinsCollector(unittest.TestCase):
    def setUp(self):
        self.finished_at = datetime(year=2018, month=1, day=1, hour=12, minute=0, tzinfo=timezone.utc)
        self.finished_at_millis = int(self.finished_at.timestamp() * 1000)
        self.default_build_url = 'http://1.2.3.4:5678/job/MyJob/1'
        self.default_api_url = 'http://1.2.3.4:5678/job/MyJob/1/wfapi/describe'
        self.default_job_status = "SUCCESS"
        self.default_collector = JenkinsCollectorAdapter('MyJob', self.default_job_status, self.default_build_url)

        self.default_build_stats_response = {
            'id': 1,
            'status': 'IN_PROGRESS',
            'durationMillis': 1000,
            'endTimeMillis': self.finished_at_millis,
        }

        self.default_stages_stats_response = [
            {
                'name': 'Preparation',
                'status': 'SUCCESS',
                'durationMillis': 1234,
            },
            {
                'name': 'Build',
                'status': 'FAILED',
                'durationMillis': 4321,
            },
        ]

    def assert_build_stats_is_valid(self, build_stats, json):
        self.assertIsNotNone(build_stats)
        self.assertIsInstance(build_stats, BuildStats)
        self.assertEqual(build_stats.job_name, 'MyJob')
        self.assertEqual(build_stats.build_id, json['id'])
        self.assertEqual(build_stats.build_url, self.default_build_url)
        self.assertEqual(build_stats.finished_at_secs, int(self.finished_at.timestamp()))
        self.assertEqual(build_stats.status, self.default_job_status)
        self.assertEqual(build_stats.duration_millis, json['durationMillis'])

    def assert_stage_stats_is_valid(self, stage_stats, json):
        self.assertIsNotNone(stage_stats)
        self.assertIsInstance(stage_stats, StageStats)
        self.assertEqual(stage_stats.name, json['name'])
        self.assertEqual(stage_stats.status, json['status'])
        self.assertEqual(stage_stats.duration_millis, json['durationMillis'])

    def test_overall_build_status_doesnt_depend_on_status_in_json(self):
       with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/1/wfapi/describe', json=self.default_build_stats_response)

            collector = JenkinsCollectorAdapter('MyJob', "SOME_STATUS", 'http://1.2.3.4:5678/job/MyJob/1')

            build_stats = collector.collect()
            self.assertEqual(build_stats.status, "SOME_STATUS")

    def test_build_stats(self):
        with requests_mock.mock() as m:
            response = self.default_build_stats_response
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()
            self.assert_build_stats_is_valid(build_stats, response)

    def test_invalid_url(self):
        with requests_mock.mock() as m:
            m.get('http://1.2.3.4:5678/job/MyJob/-1/wfapi/describe', status_code=404)

            collector = JenkinsCollectorAdapter('MyJob', self.default_job_status, 'http://1.2.3.4:5678/job/MyJob/-1')

            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_no_stages(self):
        with requests_mock.mock() as m:
            m.get(self.default_api_url, json=self.default_build_stats_response)
            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_empty_stages(self):
        with requests_mock.mock() as m:
            response = {**self.default_build_stats_response, **{ 'stages': [] }}
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 0)

    def test_stages_stats(self):
        with requests_mock.mock() as m:
            response = {
                **self.default_build_stats_response,
                **{ 'stages': self.default_stages_stats_response }
            }
            m.get(self.default_api_url, json=response)
            build_stats = self.default_collector.collect()

            self.assertIsNotNone(build_stats)
            self.assertEqual(len(build_stats.stages), 2)

            self.assert_stage_stats_is_valid(build_stats.stages[0], self.default_stages_stats_response[0])
            self.assert_stage_stats_is_valid(build_stats.stages[1], self.default_stages_stats_response[1])

    def test_overwrites_only_in_progress_status_of_post_actions_to_success(self):
        post_stages = [
            {
                'name': 'Declarative: Post Actions',
                'status': 'IN_PROGRESS',
                'durationMillis': 1234,
            },
            {
                'name': 'Declarative: Post Actions',
                'status': 'FAILED',
                'durationMillis': 1234,
            },
            {
                'name': 'Declarative: Post Actions',
                'status': 'WHATEVER',
                'durationMillis': 1234,
            }
        ]
        response = {
            **self.default_build_stats_response,
            **{ 'stages': post_stages }
        }
        with requests_mock.mock() as m:
            m.get(self.default_api_url, json=response)

            build_stats = self.default_collector.collect()
            self.assertEqual(build_stats.stages[0].status, 'SUCCESS')
            self.assertEqual(build_stats.stages[1].status, 'FAILED')
            self.assertEqual(build_stats.stages[2].status, 'WHATEVER')


class TestXmlReportCollector(unittest.TestCase):
    def setUp(self):
        self.example_json_url = 'http://1.2.3.4/build/1/test.json'
        self.example_report1_xml_url = 'http://1.2.3.4/build/1/reports/report1.xml'
        self.example_report2_xml_url = 'http://1.2.3.4/build/1/reports/report2.xml'
        self.example_report_html_url = 'http://1.2.3.4/build/1/report.html'

        self.example_json_empty = json.dumps({
            "xml_reports": [],
            "html_report": ""
        })
        self.example_json_one_report = json.dumps({
            "xml_reports": ["reports/report1.xml"],
            "html_report": "report.html"
        })
        self.example_json_two_reports = json.dumps({
            "xml_reports": ["reports/report1.xml", "reports/report2.xml"],
            "html_report": "report.html"
        })

    def test_raises_error_when_json_does_not_exist(self):
        with requests_mock.mock() as m:
            m.get(self.example_json_url, status_code=404)

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_raises_error_when_json_has_invalid_format(self):
        with requests_mock.mock() as m:
            response_text = 'Invalid JSON'
            m.get(self.example_json_url, text=response_text)

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(JSONDecodeError):
                collector.collect()

    def test_raises_error_when_json_has_invalid_structure(self):
        with requests_mock.mock() as m:
            response_text = '{}'
            m.get(self.example_json_url, text=response_text)

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(InvalidJsonFormatError):
                collector.collect()

    def test_raises_error_when_xml_reports_empty(self):
        with requests_mock.mock() as m:
            m.get(self.example_json_url, text=self.example_json_empty)

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(EmptyXmlReportsListError):
                collector.collect()

    def test_raises_error_when_stats_do_not_exist(self):
        with requests_mock.mock() as m:
            m.get(self.example_json_url, text=self.example_json_two_reports)
            m.get(self.example_report1_xml_url, text='')
            m.get(self.example_report2_xml_url, status_code=404)

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(InvalidResponseCodeError):
                collector.collect()

    def test_raises_error_when_some_fields_do_not_exist(self):
        with requests_mock.mock() as m:
            m.get(self.example_json_url, text=self.example_json_one_report)
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="4">
            </test-results>
            """
            m.get(self.example_report1_xml_url, text=response_text)

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(MissingXmlAttributeError):
                collector.collect()

    def test_raises_error_when_xml_does_not_parse(self):
        with requests_mock.mock() as m:
            m.get(self.example_json_url, text=self.example_json_one_report)
            m.get(self.example_report1_xml_url, text="this-should-not-parse")

            collector = XmlReportCollector(url=self.example_json_url)
            with self.assertRaises(ParseError):
                collector.collect()

    def test_collects_basic_stats(self):
        with requests_mock.mock() as m:
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="1" errors="0" failures="0"
                          not-run="0" inconclusive="0" ignored="0"
                          skipped="0" invalid="0">
            </test-results>
            """
            m.get(self.example_report1_xml_url, text=response_text)
            m.get(self.example_json_url, text=self.example_json_one_report)

            expected_stats = TestStats(total=1, passed=1, errors=0, failures=0, not_run=0,
                                       inconclusive=0, ignored=0, skipped=0, invalid=0,
                                       report_url=self.example_report_html_url)

            collector = XmlReportCollector(url=self.example_json_url)
            test_stats = collector.collect()
            self.assertIsNotNone(test_stats)
            assert_test_stats_equal(self, test_stats, expected_stats)

    def test_collects_multiple_stats_with_some_errors(self):
        with requests_mock.mock() as m:
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="4" errors="2" failures="0"
                          not-run="0" inconclusive="0" ignored="0"
                          skipped="0" invalid="0">
            </test-results>
            """
            m.get(self.example_report1_xml_url, text=response_text)
            response_text = """<?xml version="1.0" encoding="utf-8" standalone="no"?>
            <test-results xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                          xsi:noNamespaceSchemaLocation="nunit_schema_2.5.xsd" name="Tests"
                          total="7" errors="1" failures="2"
                          not-run="0" inconclusive="0" ignored="0"
                          skipped="1" invalid="1">
            </test-results>
            """
            m.get(self.example_report2_xml_url, text=response_text)
            m.get(self.example_json_url, text=self.example_json_two_reports)

            expected_stats = TestStats(total=11, passed=4, errors=3, failures=2, not_run=0,
                                       inconclusive=0, ignored=0, skipped=1, invalid=1,
                                       report_url=self.example_report_html_url)

            collector = XmlReportCollector(url=self.example_json_url)
            test_stats = collector.collect()
            self.assertIsNotNone(test_stats)
            assert_test_stats_equal(self, test_stats, expected_stats)


if __name__ == '__main__':
    unittest.main()
