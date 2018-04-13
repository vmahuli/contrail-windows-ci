import requests
import json
from collections import Counter
from collectors.exceptions import InvalidResponseCodeError
from stats import TestStats
from xml.etree import ElementTree


class MissingXmlAttributeError(Exception):
    pass


class InvalidJsonFormatError(Exception):
    pass


class EmptyXmlReportsListError(Exception):
    pass


class XmlReportCollector(object):
    def __init__(self, url):
        self.url = url

    def collect(self):
        resp = requests.get(self.url)
        if resp.status_code != 200:
            raise InvalidResponseCodeError()

        xml_reports_urls, html_report_url = self._parse_reports_locations(resp.text)
        xml_reports = self._get_xml_reports(xml_reports_urls)

        counts_list = [self._get_test_counts(report) for report in xml_reports]
        counts = self._sum_counts(counts_list)

        return TestStats(report_url=html_report_url, **counts)

    def _parse_reports_locations(self, locations):
        locations = json.loads(locations)

        try:
            xml_reports = locations['xml_reports']
            html_report = locations['html_report']
        except KeyError:
            raise InvalidJsonFormatError()

        if len(xml_reports) == 0:
            raise EmptyXmlReportsListError()

        xml_reports_urls = [self._get_absolute_url(url) for url in xml_reports]
        html_report_url = self._get_absolute_url(html_report)

        return xml_reports_urls, html_report_url

    def _get_absolute_url(self, url):
        base = self._get_base_url()
        return '/'.join([base, url])

    def _get_base_url(self):
        return '/'.join(self.url.split('/')[:-1])

    def _get_xml_reports(self, reports_urls):
        reports = []

        for report_url in reports_urls:
            resp = requests.get(report_url)
            if resp.status_code != 200:
                raise InvalidResponseCodeError()
            reports.append(resp.text)

        return reports

    def _sum_counts(self, counts_list):
        counts = Counter()

        for x in counts_list:
            counts.update(Counter(x))

        return dict(counts)

    def _get_test_counts(self, text):
        root = ElementTree.fromstring(text)

        counts = {}
        try:
            xml_keys = ['total', 'errors', 'failures', 'not-run', 'inconclusive',
                        'ignored', 'skipped', 'invalid']
            for xml_key in xml_keys:
                counts_key = xml_key.replace('-', '_')
                counts[counts_key] = int(root.attrib[xml_key])
        except KeyError:
            raise MissingXmlAttributeError()

        counts['passed'] = counts['total'] - sum(v for k, v in counts.items() if k != 'total')

        return counts
