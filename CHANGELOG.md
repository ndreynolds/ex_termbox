# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.1] - 2020-03-15
### Changed
- Updated dependencies (elixir_make, credo).

## [1.0.0] - 2019-03-03
The release includes small breaking changes to the termbox bindings API in order
to make working with the NIFs safer.

Specifically, the termbox bindings have been updated to guard against undefined
behavior (e.g., double initialization, trying to shut it down when it hasn't
been initialized, getting the terminal height when it's not running, etc.). New
errors have been introduced in order to achieve this, and tagged tuples are now
returned in some cases where previously only a raw value returned.

The bindings now prevent polling for events in parallel (i.e., in multiple NIF
threads), which may have caused a segfault before. One way this might have
happened before is when an `EventManager` server crashed and was restarted. The
new API manages a single long-lived polling thread.
### Changed (Breaking)
- All `Bindings` functions (except `init/0`) can now return `{:error, :not_running}`.
- Changed return types for several `Bindings` functions to accomodate new errors:
  - `Bindings.width/1` now returns `{:ok, width}` instead of `width`.
  - `Bindings.height/1` now returns `{:ok, height}` instead of `height`.
  - `Bindings.select_input_mode/1` now returns `{:ok, mode}` instead of `mode`.
  - `Bindings.select_output_mode/1` now returns `{:ok, mode}` instead of `mode`.
- Replaces `Bindings.poll_event/1` with `Bindings.start_polling/1`. The new
  function polls continuously and sends each event to the subscriber. (See also
  `Bindings.stop_polling/0` below.)
- The `EventManager` server, which manages the polling, can now crash if some
  other process is trying to simultaneously manage polling. It will attempt to
  cancel and restart polling once in order to account for the gen_server being
  restarted.
### Added
- `Bindings.stop_polling/0` provides a way to stop and later restart polling
  (for example if the original subscriber process passed to `start_polling/1`
  has died.)

## [0.3.5] - 2019-02-21
### Fixed
- Event manager's default server `name`, which makes it possible to use the
  client API to call the default server without passing a pid.
### Added
- Support for sending the event manager `%Event{}` structs in addition to the
  tuple form that the NIF sends. This provides a convenient way to trigger
  events manually when testing an ex_termbox application.

## [0.3.4] - 2019-02-03
### Added
- Allows passing alternate termobx bindings to `EventManager.start_link/1`,
  which makes it possible to test the event manager's behavior without actually
  calling the NIFs.

## [0.3.3] - 2019-01-26
### Added
- Adds `ExTermbox.EventManager.start_link/1` which supports passing through
  gen_server options.

## [0.3.2] - 2019-01-20
### Added
- Added `:esc_with_mouse` and `:alt_with_mouse` input mode constants.
- Updated documentation and tests for constants.
### Fixed
- Click handling in event viewer demo.

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
