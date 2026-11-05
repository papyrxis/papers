from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "prepare_release_assets.py"


class PrepareReleaseAssetsTests(unittest.TestCase):
    def test_duplicate_basenames_are_unique_and_content_is_preserved(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            source_dir = temporary_path / "publications"
            destination_dir = temporary_path / "release-assets"
            expected = {
                "booklets/01-data/en/main.pdf": b"booklet pdf",
                "papers/01-nature/main.pdf": b"paper pdf",
                "papers/02-summary/summary.PDF": b"summary pdf",
            }

            for relative_path, content in expected.items():
                source = source_dir / relative_path
                source.parent.mkdir(parents=True, exist_ok=True)
                source.write_bytes(content)

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(source_dir), str(destination_dir)],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertEqual(0, result.returncode, result.stderr)
            assets = sorted(destination_dir.glob("*.pdf"))
            names = [asset.name for asset in assets]

            self.assertEqual(len(expected), len(assets))
            self.assertEqual(len(names), len(set(names)))
            self.assertCountEqual(
                expected.values(),
                (asset.read_bytes() for asset in assets),
            )

            stale_asset = destination_dir / "stale.pdf"
            stale_asset.write_bytes(b"stale")
            repeated_result = subprocess.run(
                [sys.executable, str(SCRIPT), str(source_dir), str(destination_dir)],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertEqual(0, repeated_result.returncode, repeated_result.stderr)
            self.assertEqual(names, sorted(asset.name for asset in destination_dir.glob("*.pdf")))
            self.assertFalse(stale_asset.exists())

    def test_empty_source_directory_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            source_dir = temporary_path / "publications"
            source_dir.mkdir()

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(source_dir), str(temporary_path / "release-assets")],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(0, result.returncode)
            self.assertIn("No publication PDFs found", result.stderr)

    def test_destination_must_not_be_inside_source_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            source_dir = Path(temporary_directory) / "publications"
            source_dir.mkdir()

            result = subprocess.run(
                [sys.executable, str(SCRIPT), str(source_dir), str(source_dir / "release-assets")],
                check=False,
                capture_output=True,
                text=True,
            )

            self.assertNotEqual(0, result.returncode)
            self.assertIn("must not be inside", result.stderr)


if __name__ == "__main__":
    unittest.main()
