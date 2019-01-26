defmodule ExTermbox.EventManager do
  @moduledoc """
  This module implements an event manager that notifies subscribers of the
  keyboard, mouse and resize events received from the termbox API.

  It works by running a poll loop that calls out to the NIFs in
  `ExTermbox.Bindings`:

    1. The `ExTermbox.Bindings.poll_event/1` NIF is called with the event
       manager's pid.
    2. The NIF creates a new thread for the blocking poll routine and
       immediately returns with a resource representing a handle for the thread.
    3. The thread blocks until an event is received (e.g., a keypress), at which
       point it sends a message to the event manager with the event data and
       exits.
    4. The event manager notifies its subscribers of the event and returns to
       step 1.

  Example Usage:

      def event_loop do
        receive do
          {:event, %Event{ch: ?q} = event} ->
            Bindings.shutdown()
          {:event, %Event{} = event} ->
            # handle the event and wait for another...
            event_loop()
        end
      end

      {:ok, pid} = EventManager.start_link()
      :ok = EventManager.subscribe(self())
      event_loop()
  """

  alias ExTermbox.{Bindings, Event}

  use GenServer

  # Client API

  @doc """
  Starts an event manager process linked to the current process.

  Running multiple instances of the event manager process simultaneously is
  discouraged, as it could crash the NIF or cause unexpected behavior. By
  default, the process is registered with a fixed name to prevent this.
  """
  def start_link(opts \\ []) do
    server_opts = Keyword.merge([name: __MODULE__], opts)

    GenServer.start_link(__MODULE__, :ok, server_opts)
  end

  @doc """
  Subscribes the given pid to future event notifications.
  """
  def subscribe(pid \\ __MODULE__, subscriber_pid) do
    GenServer.call(pid, {:subscribe, subscriber_pid})
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    {:ok, {:ready, MapSet.new()}}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, {status, recipients}) do
    if status == :ready, do: start_polling()
    {:reply, :ok, {:polling, MapSet.put(recipients, pid)}}
  end

  @impl true
  def handle_info({:event, event_tuple}, {status, recipients}) do
    event = unpack_event(event_tuple)
    notify(recipients, event)
    # Start polling for the next event
    start_polling()
    {:noreply, {status, recipients}}
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp start_polling do
    Bindings.poll_event(self())
  end

  defp notify(recipients, event) do
    for pid <- recipients do
      send(pid, {:event, event})
    end
  end

  defp unpack_event({type, mod, key, ch, w, h, x, y}) do
    %Event{type: type, mod: mod, key: key, ch: ch, w: w, h: h, x: x, y: y}
  end
end
