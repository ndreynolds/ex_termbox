# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

The next release will include minor, but breaking changes to the termbox
bindings API in order to make working with the NIFs safer.

Specifically, the termbox bindings have been updated to guard against undefined
behavior (e.g., double initialization, trying to shut it down when it hasn't
been initialized, getting the terminal height when it's not running, etc.).

Similarly, the bindings now prevent polling for events in parallel (i.e., in
multiple NIF threads), which isn't safe. One way this might have happened before
is when an `EventManager` crashed and was restarted.

### Changed

#### Breaking
- `Bindings.poll_event/1` will now return an error (`{:error, :already_polling}`)
  if there's an existing polling thread. (See `Bindings.cancel_poll_event/0`).
- The `EventManager` server can now crash if it receives errors when attempting
  to poll. It will attempt to cancel and restart polling once in order to
  account for the gen_server being restarted.
- All `Bindings` functions (except `init/0`) can now return `{:error, :not_running}`.
- Changed return types for several `Bindings` functions to accomodate new errors:
  - `Bindings.width/1` now returns `{:ok, width}` instead of `width`.
  - `Bindings.height/1` now returns `{:ok, height}` instead of `height`.
  - `Bindings.select_input_mode/1` now returns `{:ok, mode}` instead of `mode`.
  - `Bindings.select_output_mode/1` now returns `{:ok, mode}` instead of `mode`.

### Added
- `Bindings.cancel_poll_event/0` provides a way to cancel and later restart
  polling (for example if the original process who called `poll_event/1` died.)


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
