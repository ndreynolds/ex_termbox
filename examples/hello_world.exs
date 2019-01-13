# This is a simple terminal application to show how to get started.
#
# To run this file:
#
#    mix run examples/hello_world.exs

alias ExTermbox.Bindings, as: Termbox
alias ExTermbox.{Cell, EventManager, Event, Position}

# This initializes the termbox application.
:ok = Termbox.init()

# In order to react to keyboard, click or resize events, we need to start
# the event manager and subscribe the current process to any events.
{:ok, _pid} = EventManager.start_link()
:ok = EventManager.subscribe(self())

# To render content to the screen, we use `Bindings.put_cell/1`. We pass it
# %Cell{} structs that each have a `position` and a `ch`.
#
# The `position` is a struct representing an (x, y) cartesian coordinate. The
# top-left-most cell of the screen represents the origin (0, 0).
#
# The `ch` should be an integer representing the character (e.g., ?a or 97).
# In the example, we're using charlists for this reason.
for {ch, x} <- Enum.with_index('Hello, World!') do
  :ok = Termbox.put_cell(%Cell{position: %Position{x: x, y: 0}, ch: ch})
end

for {ch, x} <- Enum.with_index('(Press <q> to quit)') do
  :ok = Termbox.put_cell(%Cell{position: %Position{x: x, y: 2}, ch: ch})
end

Termbox.present()

# When a key is pressed, it'll be sent to us by the event manager. Once we
# receive a 'q' key press, we'll shut down the application.
receive do
  {:event, %Event{ch: ?q}} ->
    :ok = Termbox.shutdown()
end
