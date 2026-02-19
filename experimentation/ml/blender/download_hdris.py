#!/usr/bin/env python3
"""
Download HDRI environment maps from Poly Haven for training data augmentation.

Usage:
    python ml/blender/download_hdris.py
    python ml/blender/download_hdris.py --count 50 --resolution 2k
    python ml/blender/download_hdris.py --output-dir ml/data/hdri

Downloads 1K resolution EXR files (~2-5 MB each) from https://polyhaven.com.
All Poly Haven assets are CC0 (public domain).
"""

import os
import sys
import json
import random
import urllib.request
import urllib.error

API_BASE = "https://api.polyhaven.com"
DEFAULT_OUTPUT_DIR = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "data", "hdri"
)


def fetch_json(url):
    """Fetch JSON from a URL with a reasonable User-Agent."""
    req = urllib.request.Request(url, headers={"User-Agent": "CubeLab/1.0"})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read())


def get_download_url(asset_id, resolution="1k"):
    """Get the download URL for an HDRI at the given resolution."""
    data = fetch_json(f"{API_BASE}/files/{asset_id}")
    return data["hdri"][resolution]["exr"]["url"]


def download_file(url, dest):
    """Download a file with progress indication."""
    req = urllib.request.Request(url, headers={"User-Agent": "CubeLab/1.0"})
    with urllib.request.urlopen(req, timeout=120) as resp:
        total = int(resp.headers.get('Content-Length', 0))
        downloaded = 0
        with open(dest, 'wb') as f:
            while True:
                chunk = resp.read(65536)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
    return downloaded


def main():
    import argparse
    parser = argparse.ArgumentParser(
        description="Download HDRI environment maps from Poly Haven (CC0)")
    parser.add_argument('--count', type=int, default=80,
                        help='Total number of HDRIs desired (default: 80)')
    parser.add_argument('--output-dir', default=DEFAULT_OUTPUT_DIR,
                        help=f'Output directory (default: {DEFAULT_OUTPUT_DIR})')
    parser.add_argument('--resolution', default='1k', choices=['1k', '2k', '4k'],
                        help='HDRI resolution (default: 1k, ~2-5 MB each)')
    parser.add_argument('--seed', type=int, default=42,
                        help='Random seed for reproducible selection')
    args = parser.parse_args()

    os.makedirs(args.output_dir, exist_ok=True)

    # Fetch catalog
    print("Fetching HDRI catalog from Poly Haven...")
    try:
        all_hdris = fetch_json(f"{API_BASE}/assets?type=hdris")
    except urllib.error.URLError as e:
        print(f"ERROR: Could not reach Poly Haven API: {e}")
        sys.exit(1)

    print(f"Found {len(all_hdris)} HDRIs available")

    # Check what's already downloaded
    existing = set()
    for f in os.listdir(args.output_dir):
        if f.lower().endswith(('.exr', '.hdr')):
            existing.add(os.path.splitext(f)[0])

    # Filter out already-downloaded
    hdri_ids = [h for h in all_hdris.keys() if h not in existing]

    needed = max(0, args.count - len(existing))
    if needed == 0:
        print(f"Already have {len(existing)} HDRIs (>= {args.count} requested). Done!")
        return

    print(f"{len(existing)} already downloaded, need {needed} more")

    # Randomly sample from available
    rng = random.Random(args.seed)
    to_download = rng.sample(hdri_ids, min(needed, len(hdri_ids)))

    print(f"Downloading {len(to_download)} HDRIs at {args.resolution} resolution...\n")

    downloaded_count = 0
    failed = []
    for i, hid in enumerate(to_download):
        dest = os.path.join(args.output_dir, f"{hid}.exr")
        try:
            url = get_download_url(hid, args.resolution)
            print(f"  [{i+1}/{len(to_download)}] {hid}...", end=" ", flush=True)
            nbytes = download_file(url, dest)
            size_mb = nbytes / (1024 * 1024)
            print(f"OK ({size_mb:.1f} MB)")
            downloaded_count += 1
        except Exception as e:
            print(f"FAILED: {e}")
            failed.append(hid)
            if os.path.exists(dest):
                os.remove(dest)

    total = len(existing) + downloaded_count
    print(f"\n{'=' * 50}")
    print(f"Download complete!")
    print(f"  Downloaded: {downloaded_count}")
    if failed:
        print(f"  Failed:     {len(failed)} ({', '.join(failed[:5])}{'...' if len(failed) > 5 else ''})")
    print(f"  Total:      {total} HDRIs in {args.output_dir}")
    print(f"{'=' * 50}")


if __name__ == "__main__":
    main()
