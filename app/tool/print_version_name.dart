// Copyright ©️ 2026 Sebastian Delmont <sd@ham2k.com>
// SPDX-License-Identifier: MPL-2.0
//
// Prints the app's human version label (kVersionName, e.g. `August '26 ALPHA`)
// to stdout — for CI to tag release manifests with the human-readable version label.
import 'package:ham2k_logger/config/version.dart';

void main() => print(kVersionName);
