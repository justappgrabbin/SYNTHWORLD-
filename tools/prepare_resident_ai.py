#!/usr/bin/env python3
"""Build pinned CPU llama.cpp bindings and fetch the bundled quantized model."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
PLUGIN_COMMIT = "fb12d7d9c0ff6274bb6c5267e86004482befc842"
MODEL_NAME = "SmolLM2-360M-Instruct-Q4_K_M.gguf"
MODEL_SHA256 = "16c7f1667fea34bacad196a57b548effcb37614db4ab5677a20c8c7b823b9e63"
MODEL_URL = "https://huggingface.co/unsloth/SmolLM2-360M-Instruct-GGUF/resolve/391ed11137586e383b1be0fab9acf01d282c2e11/" + MODEL_NAME


def run(*args):
    subprocess.run([str(a) for a in args], check=True)


def digest(path):
    h = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(4 * 1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def prepare_source(source):
    if not (source / ".git").exists():
        run("git", "clone", "https://github.com/Adriankhl/godot-llm.git", source)
        run("git", "-C", source, "checkout", PLUGIN_COMMIT)
        run("git", "-C", source, "submodule", "update", "--init", "--depth", "1")
    actual = subprocess.check_output(["git", "-C", str(source), "rev-parse", "HEAD"], text=True).strip()
    if actual != PLUGIN_COMMIT:
        raise RuntimeError("Build source does not match pinned plugin commit")
    vocab = source / "llama.cpp/llama.cpp"
    text = vocab.read_text()
    # Current upstream SmolLM and StarCoder share exactly these pretokenization regexes.
    text = text.replace('tokenizer_pre == "starcoder")',
                        'tokenizer_pre == "starcoder" || tokenizer_pre == "smollm")')
    vocab.write_text(text)
    cmake_file = source / "CMakeLists.txt"
    text = cmake_file.read_text()
    if "SYNTHWORLD_LEAN_BINDINGS" not in text:
        classes = (ROOT / "tools/resident_binding_classes.txt").read_text().strip()
        lean = '''
# SYNTHWORLD_LEAN_BINDINGS: only compile this extension's class dependency closure.
get_target_property(LEAN_SOURCES godot-cpp SOURCES)
foreach(source IN LISTS LEAN_SOURCES)
    if(source MATCHES "/gen/src/classes/" AND NOT source MATCHES "/(%s)\\\\.cpp$")
        list(REMOVE_ITEM LEAN_SOURCES "${source}")
    endif()
endforeach()
set_property(TARGET godot-cpp PROPERTY SOURCES ${LEAN_SOURCES})
''' % classes
        text = text.replace("add_subdirectory(llama.cpp EXCLUDE_FROM_ALL)",
                            "add_subdirectory(llama.cpp EXCLUDE_FROM_ALL)\n" + lean)
        cmake_file.write_text(text)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", choices=["linux", "android", "both"], default="both")
    parser.add_argument("--ndk", type=Path)
    parser.add_argument("--work", type=Path, default=Path(tempfile.gettempdir()) / "synthworld-resident-build")
    parser.add_argument("--jobs", type=int, default=4)
    args = parser.parse_args()
    model = ROOT / "game/models" / MODEL_NAME
    model.parent.mkdir(parents=True, exist_ok=True)
    if not model.exists() or digest(model) != MODEL_SHA256:
        temp = model.with_suffix(".partial")
        with urllib.request.urlopen(MODEL_URL) as response, temp.open("wb") as file:
            shutil.copyfileobj(response, file, 4 * 1024 * 1024)
        if digest(temp) != MODEL_SHA256:
            raise RuntimeError("Model checksum mismatch; refusing to package changed bytes")
        temp.replace(model)
    source = args.work / "source"
    source.parent.mkdir(parents=True, exist_ok=True)
    prepare_source(source)
    destination = ROOT / "game/addons/godot_llm/bin"
    destination.mkdir(parents=True, exist_ok=True)
    for target in (["linux", "android"] if args.target == "both" else [args.target]):
        build = args.work / target
        cmake = ["cmake", "-S", source, "-B", build, "-GNinja", "-DCMAKE_BUILD_TYPE=Release",
                 "-DLLAMA_NATIVE=OFF", "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"]
        arch = "x86_64"
        if target == "android":
            if not args.ndk:
                parser.error("--ndk is required for Android")
            cmake += ["-DCMAKE_TOOLCHAIN_FILE=" + str(args.ndk / "build/cmake/android.toolchain.cmake"),
                      "-DANDROID_ABI=arm64-v8a", "-DANDROID_PLATFORM=android-23", "-DLLAMA_OPENMP=OFF",
                      "-DCMAKE_C_FLAGS=-mcpu=generic", "-DCMAKE_CXX_FLAGS=-mcpu=generic"]
            arch = "aarch64"
        name = "libgodot_llm.%s.release.%s" % (target, arch)
        run(*cmake)
        run("cmake", "--build", build, "--target", name, "-j", args.jobs)
        shutil.copy2(build / (name + ".so"), destination)
        if target == "android":
            strip = args.ndk / "toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip"
            run(strip, destination / (name + ".so"))
    print("Resident AI binaries and checksum-verified model are ready.")


if __name__ == "__main__":
    main()
