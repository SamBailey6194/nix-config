#!/usr/bin/env python3
"""Check proposed Firestore schema with read-only samples; export no field values."""

import argparse
from contextlib import closing
import datetime
import json
import os
from pathlib import Path
import sys


def observe(node, value, special_types=()):
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
    if kind == "map":
        fields = node.setdefault("fields", {})
        for key, item in value.items():
            observe(fields.setdefault(key, {}), item, special_types)
    elif kind == "array":
        items = node.setdefault("items", {"types": set()})
        for item in value:
            observe(items, item, special_types)


def serializable(value):
    if isinstance(value, set):
        return sorted(value)
    if isinstance(value, dict):
        return {key: serializable(item) for key, item in sorted(value.items())}
    return value


EXPECTED = {
    "story_config": {
        "addedAt": (["string"], "date-time"),
        "id": (["string"], "uuid"),
        "lastCompletedChapterId": (["integer"], "int64"),
        "ownerId": (["string"], "digits-only"),
        "storyId": (["integer"], "int64"),
        "updatedAt": (["string"], "date-time"),
    },
    "story_progress": {
        "chapterIds": (["integer", "array", "null"], "chapter-ids"),
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
    if name == "chapter-ids":
        return value is None or matches_format(value, "int64") or (
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


def summarize_documents(documents, expected, special_types):
    report = {"sampledDocuments": len(documents), "fields": {}, "additionalFields": {}}
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
            observe(observed, value, special_types)
            observe(field["observed"], value, special_types)
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
                observe(extra["observed"], value, special_types)
    return report


def export_schema(db, sample, special_types, rpc_options=None):
    options = rpc_options or {"timeout": 15, "retry": None}
    collections = {}
    for name, expected in EXPECTED.items():
        print("Sampling " + name + "...", file=sys.stderr, flush=True)
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
            report["chapterIdsShapeConfirmed"] = False
            report["chapterIdsNote"] = "Scalar integer, integer array, and null are hypotheses; see observed types and array item types."
        if name == "timeline":
            # Actual discriminator values exist only in memory and never leave this process.
            groups = {}
            for data in documents:
                value = data.get("type")
                if "type" not in data:
                    group = ("missing",)
                elif isinstance(value, str):
                    group = ("string", value)
                else:
                    group = ("non-string",)
                groups.setdefault(group, []).append(data)
            report["variants"] = {}
            for index, (group, entries) in enumerate(groups.items(), 1):
                variant = summarize_documents(entries, expected, special_types)
                variant["discriminatorStatus"] = group[0]
                report["variants"][f"variant_{index}"] = variant
            report["variantNote"] = "Variant labels are anonymous and run-local. Type values are omitted; non-string types share one group."
        collections[name] = report
        print("Sampled " + str(len(documents)) + " documents.", file=sys.stderr, flush=True)
    return {
        "format": "firestore-schema-check-v1",
        "sampleLimitPerCollection": sample,
        "sampling": "First documents in default query order; not a random sample.",
        "scope": "Only the three named root collections; no collection discovery or subcollection traversal.",
        "limitations": [
            "Consistency in a sample does not prove the complete schema or field requirements.",
            "Empty results cannot distinguish an absent collection from one with no documents.",
            "Field names and dynamic map keys are retained; field values and document IDs are omitted.",
            "Date-time checks test parseable timezone-bearing ISO strings, not strict RFC 3339 validation.",
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
