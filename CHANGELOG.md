# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

## [0.3.1] - 2019-01-13
### Fixed
- Updated package paths for c_src.

## [0.3.0] - 2019-01-13
### Changed
- Updated termbox to v1.1.2.
- `char` field on `%Cell{}` struct was renamed to `ch` for consistency.
### Removed
- ExTermbox no longer includes a renderer or rendering DSL. Extracted to
  https://github.com/ndreynolds/ratatouille
