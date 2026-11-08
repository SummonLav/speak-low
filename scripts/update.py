"""Check main, prepare a verified local build, and hand it back to Launch Services."""
import ctypes
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import time

REPO = "repos/SummonLav/speak-low"
REVISION_KEY = "SpeakLowRevision"
os.environ["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"
os.environ.update(GH_PROMPT_DISABLED="1", GIT_TERMINAL_PROMPT="0")


def info(app):
    with (app / "Contents/Info.plist").open("rb") as stream:
        return plistlib.load(stream)


def github(endpoint, *args, **kwargs):
    gh = shutil.which("gh")
    if not gh:
        raise ValueError("更新需要 GitHub CLI。请安装 gh 并登录此私有仓库。")
    try:
        return subprocess.run([gh, "api", "--hostname", "github.com", f"{REPO}/{endpoint}", *args],
                              stdin=subprocess.DEVNULL, stderr=subprocess.PIPE,
                              check=True, timeout=120, **kwargs)
    except subprocess.CalledProcessError as exc:
        detail = exc.stderr.decode(errors="replace")
        if any(text in detail for text in ("401", "403", "404", "gh auth login", "GH_TOKEN")):
            raise ValueError("无法读取私有仓库，请用 gh auth login 登录有访问权的 GitHub 账号。") from exc
        raise ValueError("暂时无法连接 GitHub，请检查网络后重试。") from exc


def revision(value):
    if not re.fullmatch(r"[0-9a-f]{40}", value):
        raise ValueError("GitHub 未返回有效版本。")
    return value


def prepare(installed, directory, commit):
    commit = revision(commit)
    if not os.access(installed.parent, os.W_OK):
        raise ValueError("当前安装目录不可写，请将 App 移到可写的「应用程序」目录后重试。")
    current = info(installed)
    with tempfile.TemporaryDirectory(dir=directory) as scratch:
        source = Path(scratch) / "source"
        source.mkdir()
        archive = Path(scratch) / "source.tgz"
        with archive.open("wb") as stream:
            github(f"tarball/{commit}", stdout=stream)
        subprocess.run(["/usr/bin/tar", "-xzf", archive, "--strip-components=1", "-C", source], check=True)

        model = Path(scratch) / "model"
        bundled = installed / "Contents/Resources/Whisper"
        if bundled.is_dir():
            # APFS clones keep the installed model untouched while the builder verifies each file.
            if subprocess.run(["/bin/cp", "-cR", bundled, model], stderr=subprocess.DEVNULL).returncode:
                shutil.rmtree(model, ignore_errors=True)
                shutil.copytree(bundled, model)
        env = dict(os.environ, SPEAK_LOW_MODEL_CACHE=str(model), SPEAK_LOW_BUILD_REVISION=commit,
                   SPEAK_LOW_SIGN_IDENTITY=current.get("SpeakLowSigningIdentity", "-"))
        with tempfile.TemporaryFile() as log:
            build = subprocess.run(["/bin/bash", source / "scripts/build-app.sh", directory], cwd=source,
                                   env=env, stdin=subprocess.DEVNULL, stdout=log,
                                   stderr=subprocess.STDOUT, timeout=3600)
            if build.returncode:
                log.seek(0)
                log_dir = Path.home() / "Library/Logs/speak-low"
                log_dir.mkdir(parents=True, exist_ok=True)
                with (log_dir / "update.log").open("wb") as dest:
                    shutil.copyfileobj(log, dest)
                raise ValueError("构建失败。详情见 ~/Library/Logs/speak-low/update.log。")

    candidate = directory / "speak-low.app"
    new = info(candidate)
    if (new.get("CFBundleIdentifier") != current["CFBundleIdentifier"]
            or new.get(REVISION_KEY) != commit):
        raise ValueError("新版 App 的身份或版本与预期不符。")
    verify = ["/usr/bin/codesign", "--verify", "--strict", "--deep"]
    if current.get("SpeakLowSigningIdentity"):
        # macOS records the old app's designated requirement when the user grants access.
        original = subprocess.check_output(["/usr/bin/codesign", "-d", "-r-", installed],
                                           stderr=subprocess.DEVNULL, text=True)
        requirement = re.search(r"^#? ?designated => (.+)$", original, re.MULTILINE)
        if not requirement or subprocess.run(verify + ["-R=" + requirement[1], candidate],
                                             stderr=subprocess.DEVNULL).returncode:
            raise ValueError("新版未通过原签名身份校验，已保留当前版本。")
    else:
        subprocess.run(verify + [candidate], check=True)


def exchange(first, second):
    # Darwin RENAME_SWAP exchanges both directories atomically on the same volume.
    libc = ctypes.CDLL(None, use_errno=True)
    if libc.renamex_np(os.fsencode(first), os.fsencode(second), 2):
        err = ctypes.get_errno()
        raise OSError(err, os.strerror(err))


def relaunch(installed, directory, pid, previous):
    candidate = directory / "speak-low.app"
    swapped = False
    try:
        for _ in range(300):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.1)
        else:
            return
        if info(installed).get(REVISION_KEY, "") != previous:
            raise ValueError("安装版本已变化，请重新检查更新。")
        exchange(candidate, installed)
        swapped = True
        subprocess.run(["/usr/bin/open", "-n", installed, "--args", "--update-installed"], check=True)
    except Exception:
        if swapped:
            # If rollback itself fails, preserve the original bundle for recovery.
            exchange(candidate, installed)
        subprocess.run(["/usr/bin/open", installed, "--args", "--update-failed"], check=True)
    shutil.rmtree(directory)


if __name__ == "__main__":
    try:
        action = sys.argv[1]
        if action == "latest":
            result = github("commits/main", "--jq", ".sha", stdout=subprocess.PIPE)
            print(revision(result.stdout.decode().strip()))
        elif action == "prepare":
            prepare(Path(sys.argv[2]), Path(sys.argv[3]), sys.argv[4])
        elif action == "relaunch":
            relaunch(Path(sys.argv[2]), Path(sys.argv[3]), int(sys.argv[4]), sys.argv[5])
        else:
            sys.exit(2)
    except subprocess.TimeoutExpired:
        sys.exit("更新超时，请检查网络后重试。")
    except Exception as exc:
        sys.exit(str(exc))
