defmodule ExTermbox.EventManager do
  @moduledoc """
  This module implements an event manager that notifies subscribers of
  keyboard, mouse and resize events received from the termbox API.

  Internally, the event manager is managing a NIF-based polling routine and
  fanning out polled events to subscribers. It works likes this:

    1. The `ExTermbox.Bindings.start_polling/1` NIF is called with the event
       manager's pid.
    2. The NIF creates a background thread for the blocking polling routine and
       immediately returns with a resource representing a handle for the thread.
    3. When the polling routine receives an event (e.g., a keypress), it sends
       a message to the event manager with the event data, and then continues
       polling for the next event.
    4. The event manager receives event data from the background thread and
       notifies all of its subscribers of the event. Steps 3 and 4 are repeated
       for each event.
    5. When the event manager is terminated, `ExTermbox.Bindings.stop_polling/0`
       is called to stop polling and terminate the background thread.

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

  def stop(event_manager_server \\ __MODULE__) do
    GenServer.stop(event_manager_server)
  end

  # Server Callbacks

  @impl true
  def init(bindings) do
    _ = Process.flag(:trap_exit, true)

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
      :ok = start_polling(state.bindings)
    end

    {:reply, :ok,
     %{
       state
       | status: :polling,
         recipients: MapSet.put(state.recipients, pid)
     }}
  end

  @impl true
  def handle_info({:event, packed_event}, state) when is_tuple(packed_event) do
    handle_info({:event, unpack_event(packed_event)}, state)
  end

  def handle_info({:event, %Event{} = event}, state) do
    # Notify subscribers of the event
    :ok = notify(state.recipients, event)

    {:noreply, state}
  end

  def handle_info(_message, state) do
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, state) do
    # Try to stop polling for events to leave the system in a clean state. If
    # this fails or `terminate/2` isn't called, it will have to be done later.
    _ = state.bindings.stop_polling()
    :ok
  end

  defp start_polling(bindings) do
    case bindings.start_polling(self()) do
      {:ok, _resource} ->
        :ok

      {:error, :already_polling} ->
        with :ok <- bindings.stop_polling(),
             {:ok, _resource} <- bindings.start_polling(self()),
             do: :ok

      {:error, unhandled_error} ->
        {:error, unhandled_error}
    end
  end

  defp notify(recipients, event) do
    for pid <- recipients do
      send(pid, {:event, event})
    end

    :ok
  end

  defp unpack_event({type, mod, key, ch, w, h, x, y}) do
    %Event{type: type, mod: mod, key: key, ch: ch, w: w, h: h, x: x, y: y}
  end
end
