#!/usr/bin/env python3
"""Check proposed Firestore schema with read-only samples; export no field values."""

import argparse
from contextlib import closing
import datetime
import json
import os
from pathlib import Path
import re
import sys


TIMELINE_TYPES = ("devotion", "journal", "bible", "story")
SYNTHETIC_DATE = datetime.datetime(2000, 1, 2, 3, 4, 5)


def timezone_pattern(value):
    offset = value.utcoffset()
    if offset is None:
        return "unspecified; do not assume UTC"
    minutes = int(offset.total_seconds() / 60)
    sign = "+" if minutes >= 0 else "-"
    hours, minutes = divmod(abs(minutes), 60)
    return f"UTC{sign}{hours:02d}:{minutes:02d}; region/DST rules unknown"


def date_pattern(value):
    """Return only structural metadata and fixed synthetic examples."""
    if value is None:
        return {"representation": "null"}
    if isinstance(value, datetime.datetime):
        return {"representation": "native-timestamp", "timezone": timezone_pattern(value),
                "syntheticExample": "2000-01-02T03:04:05Z"}
    if type(value) in (int, float):
        return {"representation": "numeric; epoch unit and meaning unconfirmed"}
    if isinstance(value, dict):
        if set(value).issuperset({"seconds", "nanoseconds"}):
            return {"representation": "map with seconds/nanoseconds; epoch semantics unconfirmed"}
        return {"representation": "map; inspect nested fields"}
    if not isinstance(value, str):
        return {"representation": "non-string; inspect observed types"}
    if value == "":
        return {"representation": "empty-string"}
    # Accept timezone-naive ISO datetimes as a distinct pattern, not corruption.
    match = re.fullmatch(
        r"\d{4}-\d{2}-\d{2}([T ])\d{2}:\d{2}(:\d{2})?([.,]\d+)?(Z|[+-]\d{2}:?\d{2})?", value)
    if match:
        try:
            parsed = datetime.datetime.fromisoformat(value.replace("Z", "+00:00"))
        except ValueError:
            return {"representation": "ISO-shaped but not accepted by parser"}
        separator, seconds, fraction, zone = match.groups()
        example = "2000-01-02" + separator + "03:04"
        if seconds:
            example += ":05"
        if fraction:
            example += fraction[0] + "1" * (len(fraction) - 1)
        if zone:
            example += "Z" if zone == "Z" else ("+01:00" if ":" in zone else "+0100")
        return {"representation": "ISO-datetime-string", "timezone": timezone_pattern(parsed),
                "fractionalSecondDigits": len(fraction) - 1 if fraction else 0,
                "syntheticExample": example}
    if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        try:
            datetime.date.fromisoformat(value)
        except ValueError:
            return {"representation": "date-shaped but not accepted by parser"}
        return {"representation": "ISO-date-only-string", "timezone": "not encoded",
                "syntheticExample": "2000-01-02"}
    # Preserve locale ambiguity rather than guessing day/month order.
    candidates = []
    for date_format in ("%d/%m/%Y", "%m/%d/%Y", "%Y/%m/%d"):
        for suffix in ("", " %H:%M", " %H:%M:%S", " %H:%M:%S.%f", " %I:%M:%S %p"):
            try:
                datetime.datetime.strptime(value, date_format + suffix)
            except ValueError:
                continue
            candidates.append({"format": date_format + suffix,
                               "syntheticExample": SYNTHETIC_DATE.strftime(date_format + suffix)})
    if candidates:
        return {"representation": "slash-date-string", "timezone": "not encoded",
                "candidateFormats": candidates, "ambiguous": len(candidates) > 1}
    return {"representation": "unrecognised-string; format and validity unresolved"}


def name_hints(name):
    tokens = re.sub(r"([a-z])([A-Z])", r"\1_\2", name).lower().split("_")
    joined = "".join(tokens)
    hints = []
    if any(token in {"length", "size", "duration", "count"} for token in tokens):
        hints.append("length-or-count; units and meaning unconfirmed")
    if any(token in {"encrypted", "encryption", "cipher", "ciphertext", "nonce", "iv", "salt", "tag", "algorithm"}
           for token in tokens) or "keyid" in joined:
        hints.append("encryption-related name; encryption and key management unconfirmed")
    return hints


def observe(node, value, special_types=(), field_name=""):
    if value is None:
        kind = "null"
    elif isinstance(value, bool):
        kind = "boolean"
    elif isinstance(value, int):
        kind = "integer"
    elif isinstance(value, float):
        kind = "double"
    elif isinstance(value, str):
        kind = "string"
    elif isinstance(value, bytes):
        kind = "bytes"
    elif isinstance(value, datetime.datetime):
        kind = "timestamp"
    elif isinstance(value, dict):
        kind = "map"
    elif isinstance(value, (list, tuple)):
        kind = "array"
    else:
        kind = next((name for cls, name in special_types if isinstance(value, cls)), "unknown")

    node.setdefault("types", set()).add(kind)
    node["observations"] = node.get("observations", 0) + 1
    hints = name_hints(field_name)
    if hints:
        node["nameHints"] = hints
    is_date = bool(re.search(r"date|time", field_name, re.IGNORECASE)) or field_name.endswith("At") or field_name.lower().endswith("_at")
    if (is_date or kind == "timestamp") and kind != "array":
        signature = date_pattern(value)
        patterns = node.setdefault("datePatterns", [])
        record = next((item for item in patterns if item["pattern"] == signature), None)
        if record is None:
            record = {"pattern": signature, "observations": 0}
            patterns.append(record)
        record["observations"] += 1
    if kind == "map":
        node["mapObservations"] = node.get("mapObservations", 0) + 1
        fields = node.setdefault("fields", {})
        for key, item in value.items():
            observe(fields.setdefault(key, {}), item, special_types, key)
    elif kind == "array":
        items = node.setdefault("items", {"types": set()})
        for item in value:
            observe(items, item, special_types, field_name)


def serializable(value):
    if isinstance(value, set):
        return sorted(value)
    if isinstance(value, dict):
        result = {key: serializable(item) for key, item in sorted(value.items())}
        if "mapObservations" in value:
            for field in result.get("fields", {}).values():
                field["missingInParentMaps"] = value["mapObservations"] - field["observations"]
        return result
    return value


EXPECTED = {
    "story_config": {
        "addedAt": (["string"], "date-time"),
        "id": (["string"], "uuid"),
        "lastCompletedChapterId": (["integer", "null"], "nullable-int64"),
        "ownerId": (["string"], "digits-only"),
        "storyId": (["integer"], "int64"),
        "updatedAt": (["string"], "date-time"),
    },
    "story_progress": {
        "chapterIds": (["array", "null"], "chapter-ids"),
        "id": (["string"], "uuid"),
        "isCompleted": (["boolean"], None),
        "ownerId": (["string"], "digits-only"),
        "storyId": (["integer"], "int64"),
        "updatedAt": (["string"], "date-time"),
    },
    "timeline": {
        "createdAt": (["string"], "date-time"),
        "id": (["string"], "uuid"),
        "ownerId": (["string"], "digits-only"),
        "title": (["string"], None),
        "type": (["string"], None),
    },
}


def matches_format(value, name):
    from uuid import UUID
    if name == "int64":
        return type(value) is int and -(2 ** 63) <= value < 2 ** 63
    if name == "nullable-int64":
        return value is None or matches_format(value, "int64")
    if name == "chapter-ids":
        return value is None or (
            isinstance(value, list) and all(matches_format(item, "int64") for item in value)
        )
    if not isinstance(value, str):
        return False
    if name == "digits-only":
        return bool(value) and value.isascii() and value.isdigit()
    try:
        if name == "uuid":
            return str(UUID(value)) == value.lower()
        if name == "date-time":
            return "T" in value and datetime.datetime.fromisoformat(value.replace("Z", "+00:00")).tzinfo is not None
    except (ValueError, TypeError, OverflowError):
        return False
    return False


def related_field_paths(schema):
    result = {"lengthOrCount": [], "encryption": []}

    def walk(node, path):
        for hint in node.get("nameHints", []):
            result["lengthOrCount" if hint.startswith("length") else "encryption"].append(path)
        for name, child in node.get("fields", {}).items():
            walk(child, path + "/" + name.replace("~", "~0").replace("/", "~1"))
        if "items" in node:
            walk(node["items"], path + "/<array-item>")

    walk(schema, "")
    return result


def summarize_documents(documents, expected, special_types):
    report = {"sampledDocuments": len(documents), "fields": {}, "additionalFields": {},
              "documentSchema": {"types": set()}}
    for data in documents:
        observe(report["documentSchema"], data, special_types)
    for name, (types, format_name) in expected.items():
        field = {"expectedTypes": types, "present": 0, "missing": 0,
                 "typeMismatches": 0, "observed": {"types": set()}}
        if format_name:
            field["formatHypothesis"] = {"format": format_name, "matches": 0, "doesNotMatch": 0}
        for data in documents:
            if name not in data:
                field["missing"] += 1
                continue
            field["present"] += 1
            value = data[name]
            observed = {}
            observe(observed, value, special_types, name)
            observe(field["observed"], value, special_types, name)
            if not observed["types"].issubset(types):
                field["typeMismatches"] += 1
            if format_name:
                key = "matches" if matches_format(value, format_name) else "doesNotMatch"
                field["formatHypothesis"][key] += 1
        field["status"] = (
            "unobserved" if not field["present"] else
            "differs" if field["typeMismatches"] else "consistent-in-sample"
        )
        report["fields"][name] = field
    for data in documents:
        for name, value in data.items():
            if name not in expected:
                extra = report["additionalFields"].setdefault(name, {"present": 0, "observed": {}})
                extra["present"] += 1
                observe(extra["observed"], value, special_types, name)
    report["relatedFieldsByName"] = related_field_paths(report["documentSchema"])
    return report


def export_schema(db, sample, special_types, rpc_options=None):
    from google.cloud.firestore_v1.base_query import FieldFilter

    options = rpc_options or {"timeout": 15, "retry": None}
    collections = {}
    for name, expected in EXPECTED.items():
        print("Sampling " + name + "...", file=sys.stderr, flush=True)
        variants = {}
        if name == "timeline":
            for timeline_type in TIMELINE_TYPES:
                print("Sampling timeline type " + timeline_type + "...", file=sys.stderr, flush=True)
                query = db.collection(name).where(filter=FieldFilter("type", "==", timeline_type))
                variants[timeline_type] = [snapshot.to_dict() for snapshot in query.limit(sample).get(**options)]
            documents = [data for group in variants.values() for data in group]
        else:
            documents = [snapshot.to_dict() for snapshot in db.collection(name).limit(sample).get(**options)]
        report = summarize_documents(documents, expected, special_types)
        if name == "story_progress":
            shapes = {"missing": 0, "null": 0, "integer": 0, "array": 0, "other": 0}
            for data in documents:
                if "chapterIds" not in data:
                    shapes["missing"] += 1
                else:
                    observed = {}
                    observe(observed, data["chapterIds"], special_types)
                    kind = next(iter(observed["types"]))
                    shapes[kind if kind in shapes else "other"] += 1
            report["chapterIdsShapeCounts"] = shapes
            report["chapterIdsNote"] = "Integer arrays were observed in the previous sample. Null remains allowed by the proposed schema; other shapes are reported as differences."
        if name == "timeline":
            # Only the four explicitly requested type names may be exported.
            report["variants"] = {kind: summarize_documents(entries, expected, special_types)
                                  for kind, entries in variants.items()}
            report["variantNote"] = "Separate case-sensitive equality query per known type; other, missing, null or differently cased types are not covered. Empty groups are not proof the type never exists."
        collections[name] = report
        print("Sampled " + str(len(documents)) + " documents.", file=sys.stderr, flush=True)
    return {
        "format": "firestore-schema-check-v2",
        "sampleLimitPerCollectionOrTimelineType": sample,
        "maximumDocumentsSampled": sample * (2 + len(TIMELINE_TYPES)),
        "sampling": "First documents in default query order; not a random sample.",
        "scope": "Only the three named root collections; no collection discovery or subcollection traversal.",
        "limitations": [
            "Consistency in a sample does not prove the complete schema or field requirements.",
            "Empty results cannot distinguish an absent collection from one with no documents.",
            "Field names and dynamic map keys are retained; only the four approved timeline type values are named. Other field values and document IDs are omitted.",
            "Date patterns are inferred for date/time/At-named fields and native timestamps; examples are synthetic. Unknown patterns are not proof of corruption.",
            "Timezone offsets do not identify a timezone region or DST rules; timezone-naive strings must not be assumed UTC.",
            "Length/count and encryption name hints do not establish units, encryption algorithms, key handling or migration semantics.",
        ],
        "collections": serializable(collections),
    }


def report_error(error):
    """Report exception classes and fixed diagnostic labels, never server text."""
    causes = []
    seen = set()
    while isinstance(error, BaseException) and id(error) not in seen:
        seen.add(id(error))
        causes.append(error)
        error = getattr(error, "cause", None) or error.__cause__ or error.__context__
    print("Error chain: " + " -> ".join(type(item).__name__ for item in causes), file=sys.stderr)
    # Inspect messages in memory, but emit only these constant labels.
    message = " ".join(str(item).lower() for item in causes)
    checks = (
        (("dns", "name resolution", "name or service not known"), "DNS lookup failed."),
        (("failed to connect", "connection refused", "network is unreachable"), "Connection to the API failed."),
        (("http/2", "http2", "http_connect", "proxy"), "HTTP/2 or proxy transport failure; Firestore uses gRPC."),
        (("ssl", "tls", "certificate"), "TLS or certificate failure."),
        (("deadline", "timed out", "timeout"), "A request or retry deadline was exceeded."),
        (("quota exceeded", "quota_exceeded", "quotaexceeded"), "Firestore reports an exceeded quota."),
        (("rate limit", "rate_limit", "ratelimit", "too many requests"), "The service reports a request rate limit."),
        (("daily", "per day", "per_day", "perday"), "The error mentions a daily limit."),
        (("per minute", "per_minute", "perminute"), "The error mentions a per-minute limit."),
        (("free tier", "free_tier", "freetier"), "The error mentions a free-tier quota."),
        (("read requests", "read_requests", "readrequests", "document reads", "document_reads"), "The error mentions a read quota."),
        (("listcollectionids", "list_collection_ids"), "The error mentions collection-listing requests."),
        (("billing",), "The error mentions billing."),
        (("serviceusage.services.use", "service_usage_denied"), "The API requires Service Usage permission for the caller/quota project."),
        (("service_disabled", "api has not been used", "api is disabled"), "A required API is disabled."),
        (("insufficient authentication scopes", "access_token_scope_insufficient"), "Credentials have insufficient OAuth scopes."),
        (("permission_denied", "permission denied", "403"), "The server denied permission."),
        (("invalid_grant", "reauth", "unauthenticated"), "Authentication may need renewal."),
    )
    for needles, label in checks:
        if any(needle in message for needle in needles):
            print(label, file=sys.stderr)
    print("No server messages, document values, or document IDs logged.", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--database", default="(default)")
    parser.add_argument("--sample", type=int, default=20)
    parser.add_argument("--output", type=Path, default=Path("firestore-schema-check.json"))
    parser.add_argument("--probe", action="store_true", help="Test root collection discovery only; create no output file")
    args = parser.parse_args()
    if args.sample < 1:
        parser.error("--sample must be positive")

    from google.cloud import firestore
    from google.cloud.firestore_v1.vector import Vector

    special_types = (
        (firestore.DocumentReference, "reference"),
        (firestore.GeoPoint, "geopoint"),
        (Vector, "vector"),
    )
    try:
        if not args.probe and args.output.exists():
            raise FileExistsError()
        with closing(firestore.Client(project=args.project, database=args.database)) as db:
            if args.probe:
                print("Testing Firestore access (15 second timeout, no retries)...", file=sys.stderr, flush=True)
                next(iter(db.collections(timeout=15, retry=None)), None)
                print("Root collection discovery succeeded. No documents read or output file created.", file=sys.stderr)
                return 0
            result = export_schema(db, args.sample, special_types, {"timeout": 15, "retry": None})
        # Create only after a successful scan; never overwrite an existing file.
        descriptor = os.open(args.output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as output:
            json.dump(result, output, indent=2, ensure_ascii=True)
            output.write("\n")
    except Exception as error:
        print("Export failed.", file=sys.stderr)
        report_error(error)
        return 1
    print("Schema written successfully.", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
