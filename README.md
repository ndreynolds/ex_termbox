# ExTermbox

[![Hex.pm](https://img.shields.io/hexpm/v/ex_termbox.svg)](https://hex.pm/packages/ex_termbox)
[![Hexdocs.pm](https://img.shields.io/badge/api-hexdocs-brightgreen.svg)](https://hexdocs.pm/ex_termbox)
[![Travis CI](https://img.shields.io/travis/ndreynolds/ex_termbox/master.svg)](https://travis-ci.org/ndreynolds/ex_termbox)

Low-level [termbox](https://github.com/nsf/termbox) bindings for Elixir.

For high-level, declarative terminal UIs in Elixir, see
[Ratatouille](https://github.com/ndreynolds/ratatouille). It builds on top of
this library and the termbox API to provide an HTML-like DSL for defining views.

For the API Reference, see: [https://hexdocs.pm/ex_termbox](https://hexdocs.pm/ex_termbox).

## Getting Started

### Termbox bindings

ExTermbox implements the termbox API functions via NIFs:

* [`ExTermbox.Bindings`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html)
  * [`init/0`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#init/0)
  * [`shutdown/0`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#shutdown/0)
  * [`width/0`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#width/0)
  * [`height/0`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#height/0)
  * [`clear/0`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#clear/0)
  * [`present/0`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#present/0)
  * [`put_cell/1`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#put_cell/1)
  * [`change_cell/5`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#change_cell/5)
  * [`poll_event/1`](https://hexdocs.pm/ex_termbox/ExTermbox.Bindings.html#poll_event/1)

### Hello World

Let's go through the bundled [hello world example](./examples/hello_world.exs).
To follow along, clone this repo and edit the example. You can also create an
Elixir script in any Mix project with `ex_termbox` in the dependencies list.
Later, we'll run the example with `mix run <file>`.

In a real project, you'll probably want to use an OTP application with a proper
supervision tree, but here we'll keep it as simple as possible.

First, some aliases for the modules we'll use.

```elixir
alias ExTermbox.Bindings, as: Termbox
alias ExTermbox.{Cell, EventManager, Event, Position}
```

Next, we initialize the termbox application. This initialization should come
before any other termbox functions are called. (Otherwise, your program will
probably crash.)

```elixir
:ok = Termbox.init()
```

In order to react to keyboard, click or resize events later, we need to start
the event manager and subscribe the current process to any events. The event
manager is an abstraction over `poll_event/1` that constantly polls for events
and notifies its subscribers whenever one is received.

```elixir
{:ok, _pid} = EventManager.start_link()
:ok = EventManager.subscribe(self())
```

To render content to the screen, we use `put_cell/1`. We pass it
`%Cell{}` structs that each have a `position` and a `ch`.

The `position` is a struct representing an (x, y) cartesian coordinate. The
top-left-most cell of the screen represents the origin (0, 0).

The `ch` should be an integer representing the character (e.g., ?a or 97).
In the example, we're using charlists for this reason.

```elixir
for {ch, x} <- Enum.with_index('Hello, World!') do
  :ok = Termbox.put_cell(%Cell{position: %Position{x: x, y: 0}, ch: ch})
end

for {ch, x} <- Enum.with_index('(Press <q> to quit)') do
  :ok = Termbox.put_cell(%Cell{position: %Position{x: x, y: 2}, ch: ch})
end
```

Since Elixir is a functional language, it's good practice to avoid this sort of
imperative style in real applications. Instead, you might build and transform a
canvas defined as map or list of cells. Then, when your canvas is ready for
rendering, it can be synced to termbox via `put_cell/1` in one sweep. This is
how the Ratatouille library works.

Until now, we've only updated termbox's internal buffer. To actually render the
content to the screen, we need to call `present/0`:

```elixir
Termbox.present()
```

When a key is pressed, it'll be sent to us by the event manager. Once we receive
a 'q' key press, we'll shut down the application.

```elixir
receive do
  {:event, %Event{ch: ?q}} ->
    :ok = Termbox.shutdown()
end
```

You can use this event-handling logic to respond to events any way you
like---e.g., render different content, switch tabs, resize content, etc.

Finally, run the example like this:

```bash
$ mix run examples/hello_world.exs
```

You shuld see the text we rendered and be able to quit with 'q'.

## Installation

### From Hex

Add ExTermbox as a dependency in your project's `mix.exs`:

```elixir
def deps do
  [
    {:ex_termbox, "~> 0.3"}
  ]
end
```

The Hex package bundles a compatible version of termbox. There are some compile
hooks to automatically build and link a local copy of `ltermbox` for your
application. This should happen the first time you build ExTermbox (e.g., via
`mix deps.compile`).

So far the build has been tested on macOS and a few Linux distros. Please add
an issue if you encounter any problems with the build.

### From Source

To try out the master branch, first clone the repo:

```bash
git clone --recurse-submodules https://github.com/ndreynolds/ex_termbox.git
cd ex_termbox
```

The `--recurse-submodules` flag (`--recursive` before Git 2.13) is necessary in
order to additionally clone the termbox source code, which is required to
build this project.

Next, fetch the deps:

```
mix deps.get
```

Finally, try out the included event viewer application:

```
mix run examples/event_viewer.exs
```

If you see the application drawn and can trigger events, you're good to go. Use
'q' to quit the examples.
