import os
import sys
import shutil
import platform
import subprocess
import urllib.request
import urllib.error
import tarfile
import zipfile
import json
from mkdocs.plugins import BasePlugin
from mkdocs.structure.files import File
from mkdocs.config import config_options
from mkdocs.exceptions import PluginError


class LexPlugin(BasePlugin):
    config_scheme = (("download_if_missing", config_options.Type(bool, default=True)),)

    def __init__(self):
        self.lexd_path = "lexd"

    def on_config(self, config):
        # 1. Check if lexd is available globally
        if shutil.which("lexd"):
            self.lexd_path = "lexd"
            return config

        # 2. Check configuration
        if not self.config.get("download_if_missing", True):
            raise PluginError(
                "[mkdocs-lex] The 'lexd' binary was not found in PATH and "
                "'download_if_missing' is disabled. Either install lexd or "
                "remove 'download_if_missing: false' from your mkdocs.yml."
            )

        # 3. Setup local cache directory
        cache_dir = os.path.join(os.getcwd(), ".mkdocs_lex_cache")
        os.makedirs(cache_dir, exist_ok=True)

        # Determine the binary name inside the archive
        bin_name = "lexd.exe" if sys.platform.startswith("win") else "lexd"
        local_bin_path = os.path.join(cache_dir, bin_name)

        if os.path.exists(local_bin_path):
            self.lexd_path = local_bin_path
            return config

        print("[mkdocs-lex] Downloading lexd binary...")
        asset_url, is_zip = self._get_latest_release_url()

        archive_path = os.path.join(
            cache_dir, "lexd_archive" + (".zip" if is_zip else ".tar.gz")
        )

        try:
            req = urllib.request.Request(
                asset_url, headers={"User-Agent": "mkdocs-lex-plugin"}
            )
            with (
                urllib.request.urlopen(req) as response,
                open(archive_path, "wb") as out_file,
            ):
                shutil.copyfileobj(response, out_file)
        except Exception as e:
            raise PluginError(
                f"[mkdocs-lex] Failed to download lexd from {asset_url}: {e}"
            )

        # Extract archive
        try:
            if is_zip:
                with zipfile.ZipFile(archive_path, "r") as zf:
                    zf.extractall(cache_dir)
            else:
                with tarfile.open(archive_path, "r:gz") as tf:
                    # Prevent directory traversal attacks
                    def is_within_directory(directory, target):
                        abs_directory = os.path.abspath(directory)
                        abs_target = os.path.abspath(target)
                        prefix = os.path.commonprefix([abs_directory, abs_target])
                        return prefix == abs_directory

                    def safe_extract(
                        tar, path=".", members=None, *, numeric_owner=False
                    ):
                        for member in tar.getmembers():
                            member_path = os.path.join(path, member.name)
                            if not is_within_directory(path, member_path):
                                raise Exception("Attempted Path Traversal in Tar File")
                        tar.extractall(path, members, numeric_owner=numeric_owner)

                    safe_extract(tf, cache_dir)
        except Exception as e:
            raise PluginError(
                f"[mkdocs-lex] Failed to extract archive {archive_path}: {e}"
            )

        if not os.path.exists(local_bin_path):
            # Sometimes tar/zip extracts into a subfolder. Let's find it.
            found = False
            for root, _, files in os.walk(cache_dir):
                if bin_name in files:
                    found_bin = os.path.join(root, bin_name)
                    shutil.move(found_bin, local_bin_path)
                    found = True
                    break
            if not found:
                raise PluginError(
                    f"[mkdocs-lex] Could not find '{bin_name}' inside the downloaded archive."
                )

        # Make executable
        if not sys.platform.startswith("win"):
            os.chmod(local_bin_path, 0o755)

        self.lexd_path = local_bin_path
        print(
            f"[mkdocs-lex] Successfully downloaded and extracted lexd to {local_bin_path}"
        )

        # Cleanup archive
        try:
            os.remove(archive_path)
        except OSError:
            pass

        return config

    def _get_latest_release_url(self):
        os_name = sys.platform
        arch = platform.machine().lower()

        if arch in ("x86_64", "amd64"):
            arch = "x86_64"
        elif arch in ("aarch64", "arm64"):
            arch = "aarch64"

        target_os = ""
        if os_name.startswith("win"):
            target_os = "windows"
        elif os_name.startswith("darwin"):
            target_os = "darwin"
        elif os_name.startswith("linux"):
            target_os = "linux"

        api_url = "https://api.github.com/repos/lex-fmt/lex/releases/latest"
        try:
            req = urllib.request.Request(
                api_url, headers={"User-Agent": "mkdocs-lex-plugin"}
            )
            with urllib.request.urlopen(req) as response:
                data = json.loads(response.read().decode("utf-8"))
        except Exception as e:
            raise PluginError(
                f"[mkdocs-lex] Failed to fetch latest release from GitHub API: {e}"
            )

        assets = data.get("assets", [])
        for asset in assets:
            name = asset["name"].lower()
            if "lexd" not in name:
                continue
            if "lsp" in name:
                continue
            if name.endswith(".deb"):
                continue

            if arch in name and target_os in name:
                return asset["browser_download_url"], name.endswith(".zip")

        raise PluginError(
            f"[mkdocs-lex] Could not find a matching release asset for {arch} {os_name}."
        )

    def on_files(self, files, config):
        lex_files = []
        for root, _, filenames in os.walk(config["docs_dir"]):
            for filename in filenames:
                if filename.endswith(".lex"):
                    filepath = os.path.join(root, filename)
                    relpath = os.path.relpath(filepath, config["docs_dir"])

                    fake_md_path = relpath[:-4] + ".md"
                    f = File(
                        path=fake_md_path,
                        src_dir=config["docs_dir"],
                        dest_dir=config["site_dir"],
                        use_directory_urls=config.get("use_directory_urls", True),
                    )
                    f.abs_src_path = filepath
                    lex_files.append(f)

        files_to_keep = [f for f in files if not f.src_path.endswith(".lex")]
        files_to_keep.extend(lex_files)

        import warnings

        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            files._files = []
            for f in files_to_keep:
                files.append(f)

        return files

    def on_page_read_source(self, page, config):
        if page.file.abs_src_path.endswith(".lex"):
            print(f"[mkdocs-lex] Converting: {page.file.abs_src_path}")
            result = subprocess.run(
                [self.lexd_path, "convert", "--to", "markdown", page.file.abs_src_path],
                capture_output=True,
                text=True,
                check=True,
            )
            return result.stdout
        return None
