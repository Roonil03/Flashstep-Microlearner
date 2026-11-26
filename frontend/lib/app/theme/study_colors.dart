import 'package:flutter/material.dart';

enum StudyArea { study, library, progress, account }

/// A section's paper, lettering and emphasis colors, chosen as a set.
@immutable
class StudyTone {
  const StudyTone(this.fill, this.ink, this.accent);

  final Color fill;
  final Color ink;
  final Color accent;

  static StudyTone forBrightness(StudyArea area, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    return switch (area) {
      StudyArea.study =>
        dark
            ? const StudyTone(
              Color(0xFF22376C),
              Color(0xFFF0F3FF),
              Color(0xFFB5C9FF),
            )
            : const StudyTone(
              Color(0xFFDCE7FF),
              Color(0xFF132956),
              Color(0xFF234FB9),
            ),
      StudyArea.library =>
        dark
            ? const StudyTone(
              Color(0xFF193E32),
              Color(0xFFE4FFEE),
              Color(0xFF92DFB2),
            )
            : const StudyTone(
              Color(0xFFCAF0D5),
              Color(0xFF143B26),
              Color(0xFF166136),
            ),
      StudyArea.progress =>
        dark
            ? const StudyTone(
              Color(0xFF493918),
              Color(0xFFFFF1C8),
              Color(0xFFFFD668),
            )
            : const StudyTone(
              Color(0xFFFFE59A),
              Color(0xFF463109),
              Color(0xFF755000),
            ),
      StudyArea.account =>
        dark
            ? const StudyTone(
              Color(0xFF512C32),
              Color(0xFFFFEAEB),
              Color(0xFFFFB0A5),
            )
            : const StudyTone(
              Color(0xFFFFD5C9),
              Color(0xFF541E21),
              Color(0xFF943F35),
            ),
    };
  }
}

extension StudyColors on BuildContext {
  StudyTone studyTone(StudyArea area) =>
      StudyTone.forBrightness(area, Theme.of(this).brightness);
}
