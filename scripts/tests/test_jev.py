import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

HAS_SDK = importlib.util.find_spec("typesafe_sdk") is not None


SCRIPT = Path(__file__).parents[1] / "jev.py"
spec = importlib.util.spec_from_file_location("jev", SCRIPT)
jev = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jev)


class JevTests(unittest.TestCase):
    def test_cli_templates_and_mutually_exclusive_flags(self):
        for kind in ("all", "choice", "noul", "score"):
            flags = [] if kind == "all" else [f"--{kind}"]
            result = subprocess.run(
                [sys.executable, str(SCRIPT), *flags, "--dry-run", "--editor", "true"],
                capture_output=True, text=True, check=True,
            )
            payload = json.loads(result.stdout)
            expected = {"choice", "noul", "score"} if kind == "all" else {kind}
            self.assertEqual({q["type"] for q in payload["questions"].values()}, expected)
            self.assertEqual(jev.validate(payload), payload)
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--choice", "--score"], capture_output=True,
        )
        self.assertEqual(result.returncode, 2)

    def test_rejects_malformed_questions_and_accepts_structured_descriptions(self):
        for kind, criteria in (("choice", []), ("score", ["Only one level"]),
                               ("noul", {"yes": "Wrong key"})):
            payload = jev.template(kind)
            next(iter(payload["questions"].values()))["criteria"] = criteria
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                jev.validate(payload)
        payload = jev.template("all")
        payload["questions"]["department"]["instructions"] = {"question": "Which team?"}
        payload["questions"]["department"]["criteria"]["other"] = None
        del payload["questions"]["is_urgent"]["criteria"]
        jev.validate(payload)

    def test_editor_wait_and_quoted_arguments(self):
        self.assertEqual(jev.editor_command("zed"), ["zed", "--wait"])
        self.assertEqual(jev.editor_command("code --wait"), ["code", "--wait"])
        self.assertEqual(jev.editor_command("nvim -c 'set wrap'"), ["nvim", "-c", "set wrap"])

    def test_existing_draft_preserved_and_editor_does_not_receive_key(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.json"
            content = json.dumps(jev.template("noul"))
            path.write_text(content)
            args = argparse.Namespace(type="score", editor="true", dry_run=True, json_editor=False,
                                      model="jev-latest", request=path)
            output = io.StringIO()
            with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-secret"}), \
                    patch.object(jev.subprocess, "run") as run, \
                    contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
                jev.session(path, args)
            self.assertNotIn("TYPESAFE_API_KEY", run.call_args.kwargs["env"])
            self.assertEqual(path.read_text(), content)
            self.assertEqual(json.loads(output.getvalue()), json.loads(content))

    def test_invalid_edit_can_be_fixed_before_sending(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "draft.json"
            path.write_text("{")
            args = argparse.Namespace(type="all", editor="true", dry_run=False, json_editor=False,
                                      model="jev-latest", request=path)

            def edit(*unused, **kwargs):
                if edit.count:
                    path.write_text(json.dumps(jev.template("choice")))
                edit.count += 1
            edit.count = 0
            with patch.object(jev.subprocess, "run", side_effect=edit), \
                    patch.object(jev, "ask", side_effect=["", "s", "q"]), \
                    patch.object(jev, "send_request", return_value={"answers": {}}) as send, \
                    contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                jev.session(path, args)
            send.assert_called_once_with(jev.template("choice"))

    @unittest.skipUnless(HAS_SDK, "Run with uv --with typesafe-sdk==0.7.2 for SDK tests")
    def test_worker_uses_real_sdk_serialization_and_response_parsing(self):
        import httpx2
        from typesafe_sdk import TypeSafeClient
        requests = []
        response = {
            "model": "jev-test", "usage": {"input_tokens": 10, "output_tokens": 5},
            "answers": {
                "is_urgent": {"type": "noul", "noul": 0.95},
                "department": {"type": "choice", "choice": "billing", "confidence": 1.0,
                               "probabilities": {"billing": 1.0, "technical": 0.0, "other": 0.0}},
                "frustration": {"type": "score", "score": 1.0, "confidence": 1.0,
                                "probabilities": {"0": 0.0, "1": 1.0, "2": 0.0},
                                "legend": {"0": "Calm", "1": "Frustrated", "2": "Very angry"}},
            },
        }

        def handle(request):
            requests.append(request)
            return httpx2.Response(200, json=response)

        client = TypeSafeClient(api_key="test-secret", transport=httpx2.MockTransport(handle))
        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-secret"}), \
                patch.object(sys, "stdin", io.StringIO(json.dumps(jev.template("all")))), \
                patch("typesafe_sdk.TypeSafeClient", return_value=client), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            jev.send_worker()
        self.assertEqual(len(requests), 1)
        request = requests[0]
        self.assertEqual(str(request.url), "https://api.typesafe.ai/v1/systemone")
        self.assertEqual(request.method, "POST")
        self.assertEqual(request.headers["Authorization"], "Bearer test-secret")
        self.assertEqual(json.loads(request.content), jev.template("all"))
        self.assertEqual(json.loads(output.getvalue()), response)

    @unittest.skipUnless(HAS_SDK, "Run with uv --with typesafe-sdk==0.7.2 for SDK tests")
    def test_api_errors_redact_key(self):
        import httpx2
        from typesafe_sdk import TypeSafeClient
        client = TypeSafeClient(api_key="test-secret", transport=httpx2.MockTransport(
            lambda request: httpx2.Response(422, json={"detail": "test-secret"})))
        with patch.dict(os.environ, {"TYPESAFE_API_KEY": "test-secret"}), \
                patch.object(sys, "stdin", io.StringIO(json.dumps(jev.template("noul")))), \
                patch("typesafe_sdk.TypeSafeClient", return_value=client):
            with self.assertRaises(ValueError) as raised:
                jev.send_worker()
        self.assertNotIn("test-secret", str(raised.exception))

    def test_sender_uses_secret_wrapper_without_key_in_arguments(self):
        with patch.object(jev.shutil, "which", return_value="/bin/with-typesafe"), \
                patch.object(jev.subprocess, "run", return_value=subprocess.CompletedProcess(
                    [], 0, '{"answers": {}}', "")) as run:
            self.assertEqual(jev.send_request(jev.template("score")), {"answers": {}})
        self.assertEqual(run.call_args.args[0][0], "/bin/with-typesafe")
        self.assertEqual(json.loads(run.call_args.kwargs["input"]), jev.template("score"))

    def test_guided_primitives_preserve_case_and_validate_criteria(self):
        examples = {
            "choice": ["Route", "Which Team?", "Billing", "Invoices", "Other", "", ""],
            "noul": ["Urgent", "Is this urgent?", "Needs attention today", ""],
            "score": ["Severity", "How severe is the issue?", "Minor", "Major", ""],
        }
        for kind, answers in examples.items():
            questions = {}
            with self.subTest(kind=kind), patch("builtins.input", side_effect=answers), \
                    contextlib.redirect_stderr(io.StringIO()):
                jev.guided_question(questions, kind)
            jev.validate({"model": "jev-latest", "state": "Example", "questions": questions})
        questions = {}
        with patch("builtins.input", side_effect=examples["choice"]), \
                contextlib.redirect_stderr(io.StringIO()):
            jev.guided_question(questions, "choice")
        self.assertEqual(questions["Route"]["criteria"], {"Billing": "Invoices", "Other": None})

    def test_guided_json_state_retries_invalid_input(self):
        with patch("builtins.input", side_effect=["json", "{", ".", "json", '{"message":"Help"}', "."]), \
                contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(jev.guided_state(), {"message": "Help"})

    def test_guided_session_batches_questions_and_saves_draft(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "request.json"
            args = argparse.Namespace(type="noul", editor=None, dry_run=False, json_editor=False,
                                      model="jev-latest", request=path)
            answers = ["text", "Line One", "Line Two", ".", "Urgent", "Is this urgent?", "", "",
                       "score", "Severity", "How severe?", "Minor", "Major", ""]
            with patch("builtins.input", side_effect=answers), \
                    patch.object(jev, "ask", side_effect=["a", "s", "q"]), \
                    patch.object(jev, "send_request", return_value={"answers": {}}) as send, \
                    contextlib.redirect_stderr(io.StringIO()), contextlib.redirect_stdout(io.StringIO()):
                jev.session(path, args)
            send.assert_called_once()
            payload = json.loads(path.read_text())
            self.assertEqual(payload["state"], "Line One\nLine Two")
            self.assertEqual(set(payload["questions"]), {"Urgent", "Severity"})
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)

    def test_guided_dry_run_never_sends(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "--noul", "--dry-run"],
            input="text\nMy example\n.\n\nIs this urgent?\n\n\n", text=True,
            capture_output=True, check=True,
        )
        payload = json.loads(result.stdout)
        self.assertEqual(payload["state"], "My example")
        self.assertEqual(payload["questions"]["question_1"]["type"], "noul")


if __name__ == "__main__":
    unittest.main()
