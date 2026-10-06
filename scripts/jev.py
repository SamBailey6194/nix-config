#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = ["typesafe-sdk==0.7.2"]
# ///
"""Build a TypeSafe/Jev request with guided prompts and inspect typed answers."""

import argparse
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import tempfile


def template(kind):
    questions = {
        "department": {
            "type": "choice",
            "instructions": "Which team should handle this request?",
            "criteria": {
                "billing": "Payments, invoices and refunds",
                "technical": "Bugs, outages and integrations",
                "other": "None of the listed teams fits",
            },
        },
        "is_urgent": {
            "type": "noul",
            "instructions": "Does this request express urgency?",
            "criteria": {
                "true": "The customer expresses a time-sensitive need",
                "false": "The customer expresses no urgency",
            },
        },
        "frustration": {
            "type": "score",
            "instructions": "How frustrated is the customer?",
            "criteria": ["Calm", "Frustrated", "Very angry"],
        },
    }
    return {
        "model": "jev-latest",
        "state": {"request": "Help! My payouts have been failing for three days."},
        "questions": {
            name: question for name, question in questions.items()
            if kind == "all" or question["type"] == kind
        },
    }


def description(value):
    return isinstance(value, (str, dict, list))


def validate(payload):
    """Catch common editing mistakes; the service owns full schema validation."""
    if not isinstance(payload, dict):
        raise ValueError("The request must be a JSON object")
    if not isinstance(payload.get("model"), str) or not payload["model"].strip():
        raise ValueError("model must be a non-empty string")
    if not description(payload.get("state")):
        raise ValueError("state must be a string, object or array")
    questions = payload.get("questions")
    if not isinstance(questions, dict) or not questions:
        raise ValueError("questions must be a non-empty object keyed by question ID")
    for name, question in questions.items():
        if not isinstance(question, dict):
            raise ValueError(f"Question {name}: must be an object")
        if not description(question.get("instructions")):
            raise ValueError(f"Question {name}: instructions must be a string, object or array")
        kind = question.get("type")
        criteria = question.get("criteria")
        if kind == "choice":
            valid = (isinstance(criteria, dict) and 1 <= len(criteria) <= 255
                     and all(value is None or description(value) for value in criteria.values()))
            message = "choice criteria must map 1–255 options to descriptions or null"
        elif kind == "score":
            valid = (isinstance(criteria, list) and 2 <= len(criteria) <= 10
                     and all(description(value) for value in criteria))
            message = "score criteria must contain 2–10 ordered descriptions"
        elif kind == "noul":
            valid = ("criteria" not in question or
                     (isinstance(criteria, dict) and set(criteria) <= {"true", "false"}
                      and all(description(value) for value in criteria.values())))
            message = "noul criteria may describe true and false"
        else:
            raise ValueError(f"Question {name}: type must be choice, noul or score")
        if not valid:
            raise ValueError(f"Question {name}: {message}")
    return payload


def editor_command(override):
    editor = override or os.environ.get("VISUAL") or os.environ.get("EDITOR")
    if not editor:
        editor = next((name for name in ("nvim", "vim", "nano", "vi") if shutil.which(name)), None)
    command = shlex.split(editor or "")
    if not command:
        raise ValueError("Set VISUAL or EDITOR, or use --editor 'nvim'")
    if Path(command[0]).name in {"zed", "code", "codium"} and "--wait" not in command:
        command.append("--wait")
    return command


def send_request(payload):
    # Load the secret only in the sending process, after the editor has exited.
    wrapper = shutil.which("with-typesafe")
    command = ([wrapper] if wrapper else
               [sys.executable, str(Path(__file__).with_name("with-typesafe-env.py"))])
    result = subprocess.run(
        [*command, sys.executable, str(Path(__file__).resolve()), "--_send"],
        input=json.dumps(payload, allow_nan=False), text=True, capture_output=True,
    )
    if result.returncode:
        raise ValueError(result.stderr.strip() or "TypeSafe request failed")
    return json.loads(result.stdout)


def send_worker():
    try:
        from typesafe_sdk import Choice, Noul, Score, TypeSafeClient, TypeSafeError
    except ImportError:
        raise ValueError("The Python SDK is missing. Run 'just jev' or 'uv run scripts/jev.py'.") from None
    payload = validate(json.load(sys.stdin))
    key = os.environ.get("TYPESAFE_API_KEY")
    if not key:
        raise ValueError("Set TYPESAFE_API_KEY or provision this device's encrypted TypeSafe key")
    try:
        classes = {"choice": Choice, "noul": Noul, "score": Score}
        questions = {
            name: classes[question["type"]](**{k: v for k, v in question.items() if k != "type"})
            for name, question in payload["questions"].items()
        }
        with TypeSafeClient(timeout=60) as client:
            response = client.system_one(
                model=payload["model"], state=payload["state"], questions=questions,
            )
        result = response.model_dump(mode="json")
    except (TypeSafeError, ValueError) as error:
        raise ValueError(str(error).replace(key, "[redacted]")) from None
    print(json.dumps(result, indent=2, ensure_ascii=False, allow_nan=False))


def ask(prompt):
    print(prompt, end="", file=sys.stderr, flush=True)
    return input().strip().lower()


def prompt(label, default=None, required=False):
    while True:
        suffix = f" [{default}]" if default is not None else ""
        print(f"{label}{suffix}: ", end="", file=sys.stderr, flush=True)
        value = input().strip() or default
        if value or not required:
            return value or ""
        print("Please enter a value.", file=sys.stderr)


def select(label, options, default):
    while True:
        value = prompt(label, default).lower()
        if value in options:
            return value
        print(f"Choose one of: {', '.join(options)}", file=sys.stderr)


def multiline(label):
    print(f"{label}\nEnter multiple lines; finish with a line containing only '.'", file=sys.stderr)
    lines = []
    while True:
        line = input()
        if line == ".":
            if lines and any(line.strip() for line in lines):
                return "\n".join(lines)
            print("Please enter some content first.", file=sys.stderr)
        else:
            lines.append(line)


def guided_state():
    print("\nState is the text or data Jev will judge.", file=sys.stderr)
    while True:
        mode = select("State format: text, json, file", ("text", "json", "file"), "text")
        try:
            if mode == "text":
                return multiline("Paste or write your state:")
            if mode == "json":
                state = json.loads(multiline("Write a JSON object, array or string:"))
            else:
                path = Path(prompt("State file path", required=True)).expanduser()
                content = path.read_text(encoding="utf-8")
                state = json.loads(content) if path.suffix.lower() == ".json" else content
            if not description(state):
                raise ValueError("State must be a string, object or array")
            json.dumps(state, allow_nan=False)
            return state
        except (OSError, ValueError) as error:
            print(f"Cannot use that state: {error}", file=sys.stderr)


def guided_question(questions, kind="all"):
    print("\nChoice selects one option; Noul gives probability of yes; Score rates ordered levels.",
          file=sys.stderr)
    if kind == "all":
        kind = select("Question type: choice, noul, score", ("choice", "noul", "score"), "choice")
    name = prompt("Question ID (used to identify its answer)", f"question_{len(questions) + 1}", True)
    while name in questions:
        name = prompt("That ID already exists; enter another", required=True)
    instructions = prompt("What should Jev judge? Write one complete, focused question", required=True)
    question = {"type": kind, "instructions": instructions}
    if kind == "choice":
        print("Add options. A description is optional. Include 'other' if nothing may fit.", file=sys.stderr)
        criteria = {}
        while len(criteria) < 255:
            option = prompt("Option name (blank to finish)", required=not criteria)
            if not option:
                break
            if option in criteria:
                print("That option already exists.", file=sys.stderr)
                continue
            criteria[option] = prompt(f"Meaning of '{option}' (optional)") or None
        question["criteria"] = criteria
    elif kind == "score":
        print("Describe 2–10 levels from lowest to highest; each should stand on its own.", file=sys.stderr)
        criteria = []
        while len(criteria) < 10:
            level = prompt(f"Level {len(criteria)} (blank to finish)", required=len(criteria) < 2)
            if not level:
                break
            criteria.append(level)
        question["criteria"] = criteria
    else:
        print("Noul returns a probability from 0 (no) to 1 (yes). Definitions are optional.", file=sys.stderr)
        criteria = {}
        for outcome in ("true", "false"):
            value = prompt(f"What does {outcome} mean? (optional)")
            if value:
                criteria[outcome] = value
        if criteria:
            question["criteria"] = criteria
    questions[name] = question


def write_draft(path, payload):
    # Restrict new files, but preserve existing file permissions.
    with open(path, "w", encoding="utf-8", opener=lambda p, flags: os.open(p, flags, 0o600)) as stream:
        stream.write(json.dumps(payload, indent=2, ensure_ascii=False, allow_nan=False) + "\n")


def edit_draft(path, override):
    environment = os.environ.copy()
    environment.pop("TYPESAFE_API_KEY", None)
    while True:
        subprocess.run([*editor_command(override), str(path)], check=True, env=environment)
        try:
            payload = validate(json.loads(path.read_text(encoding="utf-8")))
            json.dumps(payload, allow_nan=False)
            return payload
        except (OSError, ValueError) as error:
            print(f"Invalid request: {error}", file=sys.stderr)
            if ask("[Enter] Edit again, [q] Quit: ") == "q":
                return None


def show_answers(response):
    print("\nJev answers:", file=sys.stderr)
    for name, answer in response.get("answers", {}).items():
        kind = answer.get("type")
        if kind == "noul":
            detail = f"probability of yes = {answer['noul']:.3f}"
        elif kind == "choice":
            detail = f"{answer['choice']} (confidence {answer['confidence']:.3f})"
        elif kind == "score":
            detail = f"score {answer['score']:.3f} (confidence {answer['confidence']:.3f})"
        else:
            detail = str(answer)
        print(f"  {name}: {detail}", file=sys.stderr)
    print(json.dumps(response, indent=2, ensure_ascii=False, allow_nan=False), flush=True)


def session(path, args):
    print("Jev request builder — compose, review, then send. Ctrl-C exits.\n"
          f"Draft: {path}", file=sys.stderr)
    use_editor = args.json_editor or args.editor is not None
    if path.exists():
        if use_editor:
            payload = edit_draft(path, args.editor)
        else:
            try:
                payload = validate(json.loads(path.read_text(encoding="utf-8")))
                json.dumps(payload, allow_nan=False)
            except (OSError, ValueError) as error:
                print(f"Invalid saved draft: {error}", file=sys.stderr)
                payload = edit_draft(path, args.editor)
    elif use_editor:
        payload = template(args.type)
        payload["model"] = args.model
        write_draft(path, payload)
        payload = edit_draft(path, args.editor)
    else:
        payload = {"model": args.model, "state": guided_state(), "questions": {}}
        guided_question(payload["questions"], args.type)
        write_draft(path, validate(payload))
    if payload is None:
        return
    if args.dry_run:
        print(json.dumps(payload, indent=2, ensure_ascii=False, allow_nan=False))
        return
    while True:
        print("\nRequest preview:", file=sys.stderr)
        print(json.dumps(payload, indent=2, ensure_ascii=False), file=sys.stderr)
        action = ask("[s] Send, [a] Add question, [t] Change state, [e] Edit JSON, [q] Quit: ")
        if action == "q":
            return
        if action == "a":
            guided_question(payload["questions"])
        elif action == "t":
            payload["state"] = guided_state()
        elif action == "e":
            edited = edit_draft(path, args.editor)
            if edited is not None:
                payload = edited
        elif action == "s":
            try:
                print("Sending to Jev…", file=sys.stderr, flush=True)
                show_answers(send_request(payload))
            except (OSError, ValueError) as error:
                print(f"Request failed: {error}", file=sys.stderr)
        write_draft(path, validate(payload))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    kinds = parser.add_mutually_exclusive_group()
    kinds.add_argument("--type", choices=["all", "choice", "noul", "score"], default="all",
                       help="first guided question type, or JSON template types (default: choose interactively)")
    for kind, meaning in (("choice", "select one option"), ("noul", "probability of yes"),
                          ("score", "rate against ordered levels")):
        kinds.add_argument(f"--{kind}", dest="type", action="store_const", const=kind,
                           help=f"start with a {kind.title()} question: {meaning}")
    parser.add_argument("--request", type=Path, help="edit/reuse this JSON file instead of a temporary draft")
    parser.add_argument("--editor", help="editor command; defaults to VISUAL, EDITOR, then a terminal editor")
    parser.add_argument("--json", dest="json_editor", action="store_true", help="start in the JSON editor instead of guided prompts")
    parser.add_argument("--model", default="jev-latest", help="model for a new guided request (default: jev-latest)")
    parser.add_argument("--dry-run", action="store_true", help="compose, validate and print JSON without sending")
    parser.add_argument("--_send", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args._send:
            send_worker()
        elif args.request:
            session(args.request.resolve(), args)
        else:
            with tempfile.TemporaryDirectory(prefix="jev-") as directory:
                session(Path(directory) / "request.json", args)
    except (EOFError, KeyboardInterrupt):
        print("\nSession closed.", file=sys.stderr)
        return 130
    except (OSError, ValueError, subprocess.CalledProcessError) as error:
        print(f"jev: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
