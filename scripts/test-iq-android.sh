#!/bin/bash
# Copyright ©️ 2026 Robert Jackson <me@rwjblue.com>
# SPDX-License-Identifier: MPL-2.0
# Called only by scripts/test.sh --native-iq android, after package preparation.
# Build the patched module with HaLo's AGP/Kotlin versions and Android flags,
# without configuring unrelated app plugins. SDK/JDK locations are supplied
# by the caller.
set -euo pipefail
ROOT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
IQ_PROJECT="$(mktemp -d)"
trap 'rm -rf "$IQ_PROJECT"' EXIT
IQ_FLUTTER_ROOT="$(mise where flutter)"
export HALO_IQ_ROOT="$ROOT_DIR" HALO_IQ_PROJECT="$IQ_PROJECT" HALO_IQ_FLUTTER_ROOT="$IQ_FLUTTER_ROOT"
python3 - <<'PY'
import json
import os
from pathlib import Path
import re
import shutil

root = Path(os.environ['HALO_IQ_ROOT'])
project = Path(os.environ['HALO_IQ_PROJECT'])
flutter = Path(os.environ['HALO_IQ_FLUTTER_ROOT'])
settings = (root / 'app/android/settings.gradle.kts').read_text()
def version(plugin):
    match = re.search(r'id\("' + re.escape(plugin) + r'"\) version "([^"]+)"', settings)
    if not match:
        raise SystemExit('Cannot determine app Gradle plugin version: ' + plugin)
    return match.group(1)
def quoted(value):
    return json.dumps(str(value)).replace('$', '\\$')

agp = version('com.android.application')
kotlin = version('org.jetbrains.kotlin.android')
engine_version = '1.0.0-' + (flutter / 'bin/cache/engine.stamp').read_text().strip()
realm = (flutter / 'bin/cache/engine.realm').read_text().strip()
realm = realm + '/' if realm else ''
flutter_repository = os.environ.get('FLUTTER_STORAGE_BASE_URL', 'https://storage.googleapis.com').rstrip('/') + '/' + realm + 'download.flutter.io'
wrapper = flutter / 'bin/cache/artifacts/gradle_wrapper'
if not (wrapper / 'gradlew').is_file():
    raise SystemExit('Flutter Android artifacts are missing; run `mise exec -- flutter precache --android` first.')
module = root / 'packages/record_android_patched/android'
report_root = root / 'app/build/iq-native-android'
report_root.mkdir(parents=True, exist_ok=True)
# Do not mistake reports from an earlier successful run for this run's result.
for folder in ['test-results', 'reports/tests']:
    shutil.rmtree(report_root / folder, ignore_errors=True)
(project / 'settings.gradle.kts').write_text(f'''
pluginManagement {{
    repositories {{ google(); mavenCentral(); gradlePluginPortal() }}
    plugins {{
        id("com.android.library") version "{agp}"
        id("org.jetbrains.kotlin.android") version "{kotlin}"
    }}
}}
rootProject.name = "halo_iq_native_validation"
include(":record_android")
project(":record_android").projectDir = file({quoted(module)})
''')
(project / 'build.gradle.kts').write_text(f'''
plugins {{
    id("com.android.library") apply false
    id("org.jetbrains.kotlin.android") apply false
}}
allprojects {{ repositories {{ google(); mavenCentral(); maven {{ url = uri({quoted(flutter_repository)}) }} }} }}
subprojects {{
    layout.buildDirectory.set(file({quoted(report_root)}))
    afterEvaluate {{
        dependencies.add("debugImplementation", "io.flutter:flutter_embedding_debug:{engine_version}")
    }}
}}
''')
# Preserve the shipping flags, including android.builtInKotlin=false. The
# harness deliberately does not inject the Kotlin plugin into the module.
shutil.copy2(root / 'app/android/gradle.properties', project / 'gradle.properties')
for relative in ['gradlew', 'gradlew.bat', 'gradle/wrapper/gradle-wrapper.jar']:
    dest = project / relative
    dest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(wrapper / relative, dest)
shutil.copy2(root / 'app/android/gradle/wrapper/gradle-wrapper.properties', project / 'gradle/wrapper/gradle-wrapper.properties')
print(f'Native Android module: AGP {agp}, Kotlin {kotlin}; reports: {report_root}', flush=True)
PY
"$IQ_PROJECT/gradlew" -p "$IQ_PROJECT" :record_android:compileDebugKotlin :record_android:compileDebugUnitTestKotlin :record_android:testDebugUnitTest --console=plain
python3 - <<'PY'
import os
from pathlib import Path
import xml.etree.ElementTree as ET
reports = Path(os.environ['HALO_IQ_ROOT']) / 'app/build/iq-native-android/test-results/testDebugUnitTest'
suites = [ET.parse(path).getroot() for path in sorted(reports.glob('TEST-*.xml'))]
required = {'IqCaptureValidationTest', 'IqFormatRequestTest', 'AudioInterruptionPolicyTest', 'RecorderControllerTest'}
observed = {suite.attrib['name'].split('.')[-1] for suite in suites if int(suite.attrib['tests']) > int(suite.attrib.get('skipped', 0))}
if not required.issubset(observed):
    raise SystemExit('Missing nonempty native suites: ' + ', '.join(sorted(required - observed)))
counts = {key: sum(int(suite.attrib.get(key, 0)) for suite in suites) for key in ['tests', 'failures', 'errors', 'skipped']}
print(f'Android native result: {counts}; XML reports: {reports}')
if counts['tests'] <= counts['skipped'] or counts['failures'] or counts['errors']:
    raise SystemExit('Native Android test reports did not pass.')
PY
