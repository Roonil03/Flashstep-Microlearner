<div align="center">
  <img src="frontend/assets/LogoWithoutText_WithoutBGLarge.png" alt="Flashstep Microlearner" />

# Flashstep Microlearner
A local-first microlearning and flashcard app built with Flutter and Go (Gin), designed for fast review sessions, deck management, spaced repetition, sync, and learner analytics.
</div>

## What this project is

Flashstep Microlearner is a full-stack flashcard learning platform with:

- a Flutter frontend for Android and cross-platform clients
- a Go backend with PostgreSQL
- local-first data storage through Drift on the device
- cloud sync for decks, cards, review history, and analytics
- bounded sync uploads and paged reconciliation that finds late offline changes across devices
- spaced repetition review workflows
- public deck browsing and editable personal copies
- a safe, nine-step navigation guide for new signups, replayable from Settings
- accessible navigation controls and responsive review settings

The goal of the project is to make short, repeatable learning sessions feel smooth, fast, and reliable, even when connectivity is inconsistent.

<!-- Current release: **1.1.0**.

Version 1.1.0 includes backend sync optimizations and additive manifest/fetch APIs. Deploy the updated backend before distributing the frontend; existing clients remain compatible, and no database migration is required. See the release notes for local benchmark results and validation limits. -->

## Documentation

- [Installation Guide](INSTALL.md)
- [Release Notes 1.1.0](./docs/release-1.1.0.md)
- [Backend API Reference](./backend/api/API.md)
- [Architecture and Design Docs](docs/)


## License

- This project is licensed under the terms described in [MIT License](LICENSE).
- The images for the logo are under the [CC SA 4.0](./frontend/assets/LICENSE).

## Contributors:
- Project Creator and maintainer: [Roonil03](https://github.com/Roonil03)

> This project was made as part of the Advanced Technology Lab Project
