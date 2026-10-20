import contextlib
import datetime
import importlib.util
import io
import json
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    'schema_export', Path(__file__).parents[1] / 'firestore-schema-export.py')
schema = importlib.util.module_from_spec(spec)
spec.loader.exec_module(schema)


class SchemaExportTests(unittest.TestCase):
    def test_date_patterns_describe_structure_without_retaining_dates(self):
        for date in ('2026-10-01T11:49:03.253729', '2026-10-01 11:49:03.253729Z',
                     '2026-10-01T11:49:03+0130', '2026-10-01', '01/10/2026 11:49:03'):
            with self.subTest(date=date):
                result = schema.date_pattern(date)
                self.assertNotIn(date, json.dumps(result))
                self.assertNotIn('2026', json.dumps(result))
                self.assertNotIn('unrecognised', result['representation'])
        naive = schema.date_pattern('2026-10-01T11:49:03')
        self.assertIn('unspecified', naive['timezone'])
        offset = schema.date_pattern('2026-10-01T11:49:03+01:30')
        self.assertIn('UTC+01:30', offset['timezone'])
        self.assertTrue(schema.date_pattern('01/10/2026')['ambiguous'])
        self.assertIn('unrecognised', schema.date_pattern('PRIVATE_DATE_CONTENT')['representation'])

    def test_nested_fields_dates_arrays_and_name_hints(self):
        documents = [
            {'detail': {'createdAt': '2026-10-01 11:49:03', 'length': 987654,
                        'encryption': {'ciphertext': 'PRIVATE_CIPHERTEXT', 'keyId': 'PRIVATE_KEY_ID'}},
             'entries': [{'updatedAt': '2026-10-01T11:49:03Z'}, {'duration': 987654}],
             'format': 'PRIVATE_FORMAT'},
            {'detail': {'length': None}, 'entries': []},
        ]
        result = schema.serializable(schema.summarize_documents(documents, {}, ()))
        detail = result['documentSchema']['fields']['detail']
        self.assertEqual(detail['fields']['createdAt']['missingInParentMaps'], 1)
        self.assertEqual(detail['fields']['length']['types'], ['integer', 'null'])
        self.assertIn('/detail/length', result['relatedFieldsByName']['lengthOrCount'])
        self.assertIn('/entries/<array-item>/duration', result['relatedFieldsByName']['lengthOrCount'])
        self.assertIn('/detail/encryption/keyId', result['relatedFieldsByName']['encryption'])
        self.assertNotIn('datePatterns', result['documentSchema']['fields']['format'])
        self.assertIn('datePatterns', result['documentSchema']['fields']['entries']['items']['fields']['updatedAt'])
        output = json.dumps(result)
        for value in ('PRIVATE', '987654', '2026-10-01'):
            self.assertNotIn(value, output)

    def test_null_chapter_id_and_array_shape(self):
        result = schema.serializable(schema.summarize_documents(
            [{'lastCompletedChapterId': None}, {'lastCompletedChapterId': 7}],
            schema.EXPECTED['story_config'], ()))
        field = result['fields']['lastCompletedChapterId']
        self.assertEqual(field['typeMismatches'], 0)
        self.assertEqual(field['formatHypothesis']['matches'], 2)
        progress = schema.serializable(schema.summarize_documents(
            [{'chapterIds': [1, 2]}, {'chapterIds': None}, {'chapterIds': 3}, {'chapterIds': [True]}],
            schema.EXPECTED['story_progress'], ()))
        self.assertEqual(progress['fields']['chapterIds']['typeMismatches'], 1)
        self.assertEqual(progress['fields']['chapterIds']['formatHypothesis']['doesNotMatch'], 2)

    def test_timestamp_and_invalid_dates(self):
        node = {}
        schema.observe(node, datetime.datetime(2026, 10, 1, tzinfo=datetime.timezone.utc))
        self.assertEqual(node['datePatterns'][0]['pattern']['representation'], 'native-timestamp')
        self.assertNotIn('2026', json.dumps(schema.serializable(node)))
        self.assertIn('not accepted', schema.date_pattern('2026-99-99')['representation'])
        self.assertIn('not accepted', schema.date_pattern('2026-99-99T99:99:99')['representation'])

    def test_samples_each_known_type_with_bounded_queries_and_no_id_access(self):
        calls = []
        rows = {'story_config': [{'lastCompletedChapterId': None}],
                'story_progress': [{'chapterIds': [1, 2]}],
                'timeline': [{'type': 'journal', 'title': 'PRIVATE_TITLE', 'length': 987654},
                             {'type': 'story', 'createdAt': '2026-10-01T01:02:03'},
                             {'type': 'PRIVATE_UNKNOWN_TYPE', 'secret': 'PRIVATE_VALUE'}]}

        class Filter:
            def __init__(self, field_path, op_string, value):
                self.field_path, self.op_string, self.value = field_path, op_string, value

        class Snapshot:
            def __init__(self, data): self.data = data
            def to_dict(self): return self.data
            @property
            def id(self): raise AssertionError('Must not read document IDs')

        class Query:
            def __init__(self, name): self.name, self.filter, self.count = name, None, None
            def where(self, *, filter): self.filter = filter; return self
            def limit(self, count): self.count = count; return self
            def get(self, **options):
                self_type = self.filter.value if self.filter else None
                calls.append((self.name, self_type, self.count, options))
                if self.filter:
                    assert (self.filter.field_path, self.filter.op_string) == ('type', '==')
                return [Snapshot(data) for data in rows[self.name]
                        if not self.filter or data.get('type') == self_type][:self.count]

        db = SimpleNamespace(collection=Query)
        fake_sdk = SimpleNamespace(FieldFilter=Filter)
        log = io.StringIO()
        with patch.dict(sys.modules, {'google.cloud.firestore_v1.base_query': fake_sdk}), \
                contextlib.redirect_stderr(log):
            result = schema.export_schema(db, 20, ())
        self.assertEqual(len(calls), 6)
        self.assertEqual({call[1] for call in calls if call[0] == 'timeline'}, set(schema.TIMELINE_TYPES))
        self.assertTrue(all(call[2] == 20 and call[3]['retry'] is None for call in calls))
        variants = result['collections']['timeline']['variants']
        self.assertEqual(set(variants), set(schema.TIMELINE_TYPES))
        self.assertEqual(variants['bible']['sampledDocuments'], 0)
        self.assertEqual(variants['journal']['sampledDocuments'], 1)
        self.assertIn('length', variants['journal']['documentSchema']['fields'])
        output = json.dumps(result) + log.getvalue()
        self.assertNotIn('PRIVATE', output)
        self.assertNotIn('987654', output)
        self.assertEqual(result['maximumDocumentsSampled'], 120)

    def test_safe_errors_keep_server_messages_private(self):
        log = io.StringIO()
        with contextlib.redirect_stderr(log):
            schema.report_error(RuntimeError('PRIVATE_ID quota exceeded'))
        self.assertIn('exceeded quota', log.getvalue())
        self.assertNotIn('PRIVATE_ID', log.getvalue())


if __name__ == '__main__':
    unittest.main()
