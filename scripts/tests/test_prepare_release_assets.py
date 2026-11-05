from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "scripts"))

from prepare_release_assets import prepare_release_assets


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

            first_assets = prepare_release_assets(source_dir, destination_dir)
            first_names = [asset.name for asset in first_assets]

            self.assertEqual(len(expected), len(first_assets))
            self.assertEqual(len(first_names), len(set(first_names)))
            self.assertCountEqual(
                expected.values(),
                (asset.read_bytes() for asset in first_assets),
            )

            stale_asset = destination_dir / "stale.pdf"
            stale_asset.write_bytes(b"stale")
            second_assets = prepare_release_assets(source_dir, destination_dir)

            self.assertEqual(first_names, [asset.name for asset in second_assets])
            self.assertFalse(stale_asset.exists())

    def test_empty_source_directory_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            temporary_path = Path(temporary_directory)
            source_dir = temporary_path / "publications"
            source_dir.mkdir()

            with self.assertRaisesRegex(ValueError, "No publication PDFs found"):
                prepare_release_assets(source_dir, temporary_path / "release-assets")

    def test_destination_must_not_be_inside_source_directory(self) -> None:
        with tempfile.TemporaryDirectory() as temporary_directory:
            source_dir = Path(temporary_directory) / "publications"
            source_dir.mkdir()

            with self.assertRaisesRegex(ValueError, "must not be inside"):
                prepare_release_assets(source_dir, source_dir / "release-assets")


if __name__ == "__main__":
    unittest.main()
