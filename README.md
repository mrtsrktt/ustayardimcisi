# Usta Yardımcısı

**Flutter-based woodworking assistant for Turkish carpentry professionals.**

A desktop (Windows) application that automates the full workflow from kitchen/cabinet design to cut list generation — built specifically for Turkish craftsmen who don't use CAD software.

## What it does

Carpenters in Turkey manually calculate cut lists, material costs, and edge banding for every job — a slow, error-prone process. Usta Yardımcısı automates this:

- **Sketch → Plan:** Reads hand-drawn sketches or room photos via Vision AI, extracts measurements (with mandatory craftsman approval)
- **Cabinet design:** Parametric module system — 14 standard cabinet types (base, wall, tall units) with Turkish industry-standard dimensions
- **Cut optimization:** 2D guillotine bin-packing algorithm (Dart isolate), typically achieving <12% material waste on 2100×2800mm panels
- **Reports:** Generates PDF cut plans + Excel sheets ready to send directly to the cutting workshop via WhatsApp
- **Cost estimation:** Material pricing database with offline fallback; generates customer quote PDF with profit margin control

## Who it's for

Independent woodworking craftsmen and small cabinet workshops in Turkey. The UI is intentionally designed for users unfamiliar with technology — single-question screens, large touch targets (min 56px), plain Turkish ("Kesim Planı", not "Cut Optimization").

## Tech stack

- **Flutter** (Windows primary; shared codebase for future Android/iOS)
- **State:** Riverpod
- **Local DB:** SQLite via drift
- **Cut optimization:** Custom 2D bin-packing in Dart isolate (FFD + strip placement + local improvement)
- **AI:** Gemini Flash Image API for photorealistic renders; Vision LLM for sketch reading
- **Reports:** Vector PDF (cut diagrams) + xlsx export

## Current status

Core modules complete: customer/project management, sketch reading, cabinet module engine (14 modules), cut optimizer, cost reporting, PDF/Excel export, WhatsApp sharing.

In progress: AI render integration, voice/text revision loop.

## Development

```bash
# Requires Flutter Windows with Developer Mode enabled
flutter pub get
flutter run -d windows
```

Unit tests for all module formulas:
```bash
flutter test test/modules/
```

## Background

Built and maintained by [Murat Sarıkurt](https://github.com/mrtsrktt) of [3M Atölye](https://github.com/mrtsrktt), a digital development agency based in Turkey. Developed iteratively with Claude Code as the primary AI coding assistant.

## License

MIT
