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

  use GenServer

  alias ExTermbox.Event

  @default_bindings ExTermbox.Bindings

  @default_server_opts [name: __MODULE__]

  # Client API

  @doc """
  Starts an event manager process linked to the current process.

  Running multiple instances of the event manager process simultaneously is
  discouraged, as it could crash the NIF or cause unexpected behavior. By
  default, the process is registered with a fixed name to prevent this.
  """
  def start_link(opts \\ []) do
    {bindings, server_opts} = Keyword.pop(opts, :bindings, @default_bindings)

    server_opts_with_defaults = Keyword.merge(@default_server_opts, server_opts)

    GenServer.start_link(__MODULE__, bindings, server_opts_with_defaults)
  end

  @doc """
  Subscribes the given subscriber pid to future event notifications.
  """
  def subscribe(event_manager_server \\ __MODULE__, subscriber_pid) do
    GenServer.call(event_manager_server, {:subscribe, subscriber_pid})
  end

  # Server Callbacks

  @impl true
  def init(bindings) do
    {:ok,
     %{
       bindings: bindings,
       status: :ready,
       recipients: MapSet.new()
     }}
  end

  @impl true
  def handle_call({:subscribe, pid}, _from, state) do
    if state.status == :ready do
      start_polling(state.bindings)
    end

    {:reply, :ok,
     %{
       state
       | status: :polling,
         recipients: MapSet.put(state.recipients, pid)
     }}
  end

  @impl true
  def handle_info({:event, event_tuple}, state) do
    # Unpack and notify subscribers
    event = unpack_event(event_tuple)
    notify(state.recipients, event)

    # Start polling for the next event
    start_polling(state.bindings)

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  defp start_polling(bindings) do
    bindings.poll_event(self())
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
