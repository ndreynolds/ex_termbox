defmodule ExTermbox.Bindings do
  @moduledoc """
  Provides the low-level bindings to the termbox library. This module loads the
  NIFs defined in `c_src/` and thinly wraps the C interface.

  For event-handling, it's recommended to use the `ExTermbox.EventManager` API
  instead of the raw interface exposed here.

  For more complex applications, it's recommended to use the high-level
  rendering API provided by Ratatouille (a terminal UI kit based on the bindings
  here). Ratatouille manages things like initialization, updates and shutdown
  automatically, and provides a declarative, HTML-like interface for rendering
  content to the screen. See the repo for details:

  <https://github.com/ndreynolds/ratatouille>

  See also the termbox header file for additional documentation of the functions
  here:

  <https://github.com/nsf/termbox/blob/master/src/termbox.h>

  Note that the "NIF <function>/<arity> not loaded" messages below are fallbacks
  normally replaced by the natively-implemented functions at load. If you're
  seeing this message, it means the native bindings could not be loaded. Please
  open an issue with the error and relevant system information.

  ### Event Polling

  The event polling API differs slightly from the termbox API in order to make
  it in the Erlang ecosystem. Instead of blocking poll calls, it uses
  asynchronous message passing to deliver events to the caller.

  It's recommended to use the `ExTermbox.EventManager` gen_server to subscribe
  to terminal events instead of using these bindings directly. It supports
  multiple subscriptions and more gracefully handles errors.

  #### Implementation Notes

  In the `start_polling/1` NIF, an OS-level thread is created which performs the
  blocking event polling (i.e., a `select` call). This allows the NIF to return
  quickly and avoid causing the scheduler too much trouble. It would be very bad
  to block the scheduler thread until an event is received.

  While using threads solves this problem, it unfortunately also introduces new
  ones. The bindings implement some locking mechanisms to try to coordinate
  threading logic and prevent polling from occurring simultaneously, but this
  sort of logic is hard to get right (one of the reasons we use Elixir/Erlang).
  No issues are currently known, but please report any you happen to encounter.

  #### Timeouts

  You might have noticed that there's no binding for `tb_peek_event` (which
  accepts a timeout). That's because it's easy enough to implement a timeout
  ourselves with `start_polling/1` and `receive` with `after`, e.g.:

      {:ok, _resource} = Bindings.start_polling(self())

      receive do
        {:event, event} ->
          # handle the event...
      after
        1_000 ->
          :ok = Bindings.stop_polling(self())
          # do something else...
      end

  """

  alias ExTermbox.{Cell, Constants, Position}

  @on_load :load_nifs

  def load_nifs do
    case :code.priv_dir(:ex_termbox) do
      {:error, _} = err ->
        err

      path ->
        path
        |> Path.join("termbox_bindings")
        |> to_charlist()
        |> :erlang.load_nif(0)
    end
  end

  @doc """
  Initializes the termbox library. Must be called before any other bindings are
  called.

  Returns `:ok` on success and otherwise one of the following errors:

  * `{:error, :already_running} - the library was already initialized.
  * `{:error, code}` - where code is an integer error code from termbox.
  """
  @spec init :: :ok | {:error, integer() | :already_running}
  def init do
    error("NIF init/0 not loaded")
  end

  @doc """
  Finalizes the termbox library. Should be called when the terminal application
  is exited, and before your program or OTP application stops.

  Returns `:ok` on success and otherwise one of the following errors:

  * `{:error, :not_running} - the library can not be shut down because it is not
    initialized.
  * `{:error, code}` - where `code` is an integer error code from termbox.
  """
  @spec shutdown :: :ok | {:error, integer() | :not_running}
  def shutdown do
    error("NIF shutdown/0 not loaded")
  end

  @doc """
  Returns `{:ok, width}` where `width` is the width of the terminal window in
  characters.

  If termbox was not initialized, returns `{:error, :not_running}` (call
  `init/0` first).
  """
  @spec width :: {:ok, integer()} | {:error, :not_running}
  def width do
    error("NIF width/0 not loaded")
  end

  @doc """
  Returns `{:ok, height}` where `height` is the height of the terminal window in
  characters.

  If termbox was not initialized, returns `{:error, :not_running}` (call
  `init/0` first).
  """
  @spec height :: {:ok, integer()} | {:error, :not_running}
  def height do
    error("NIF height/0 not loaded")
  end

  @doc """
  Clears the internal back buffer, setting the foreground and background to the
  defaults, or those specified by `set_clear_attributes/2`.

  Returns `:ok` if successful. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec clear :: :ok | {:error, :not_running}
  def clear do
    error("NIF clear/0 not loaded")
  end

  @doc """
  Sets the default foreground and background colors used when `clear/0` is
  called.

  Returns `:ok` if successful. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec set_clear_attributes(Constants.color(), Constants.color()) ::
          :ok | {:error, :not_running}
  def set_clear_attributes(_fg, _bg) do
    error("NIF set_clear_attributes/2 not loaded")
  end

  @doc """
  Synchronizes the internal back buffer and the terminal.

  Returns `:ok` if successful. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec present :: :ok | {:error, :not_running}
  def present do
    error("NIF present/0 not loaded")
  end

  @doc """
  Sets the position of the cursor to the coordinates `(x, y)`, or hide the
  cursor by passing `ExTermbox.Constants.hide_cursor/0` for both x and y.

  Returns `:ok` if successful. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec set_cursor(non_neg_integer(), non_neg_integer()) ::
          :ok | {:error, :not_running}
  def set_cursor(_x, _y) do
    error("NIF set_cursor/2 not loaded")
  end

  @doc """
  Puts a cell in the internal back buffer at the cell's position. Note that this is
  implemented in terms of `change_cell/5`.

  Returns `:ok` if successful. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec put_cell(Cell.t()) :: :ok | {:error, :not_running}
  def put_cell(%Cell{position: %Position{x: x, y: y}, ch: ch, fg: fg, bg: bg}) do
    change_cell(x, y, ch, fg, bg)
  end

  @doc """
  Changes the attributes of the cell at the specified position in the internal
  back buffer. Prefer using `put_cell/1`, which supports passing an
  `ExTermbox.Cell` struct.

  Returns `:ok` if successful. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec change_cell(
          non_neg_integer(),
          non_neg_integer(),
          non_neg_integer(),
          Constants.color(),
          Constants.color()
        ) :: :ok | {:error, :not_running}
  def change_cell(_x, _y, _ch, _fg, _bg) do
    error("NIF change_cell/5 not loaded")
  end

  @doc """
  Sets or retrieves the input mode (see `ExTermbox.Constants.input_modes/0`).
  See the [termbox source](https://github.com/nsf/termbox/blob/master/src/termbox.h)
  for additional documentation.

  Returns `{:ok, input_mode}` when successful, where `input_mode` is an integer
  representing the current mode. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec select_input_mode(Constants.input_mode()) ::
          {:ok, integer()} | {:error, :not_running}
  def select_input_mode(_mode) do
    error("NIF select_input_mode/1 not loaded")
  end

  @doc """
  Sets or retrieves the output mode (see `ExTermbox.Constants.output_modes/0`).
  See the [termbox source](https://github.com/nsf/termbox/blob/master/src/termbox.h)
  for additional documentation.

  Returns `{:ok, output_mode}` when successful, where `output_mode` is an
  integer representing the current mode. If termbox was not initialized, returns
  `{:error, :not_running}` (call `init/0` first).
  """
  @spec select_output_mode(Constants.output_mode()) ::
          {:ok, integer()} | {:error, :not_running}
  def select_output_mode(_mode) do
    error("NIF select_output_mode/1 not loaded")
  end

  @doc """
  Starts polling for terminal events asynchronously. The function accepts a PID
  as argument and returns immediately. When an event is received, it's sent to
  the specified process. It continues polling until either `stop_polling/0` or
  `shutdown/0` is called. An error is returned when this function is called
  again before polling has been stopped.

  If successful, returns `{:ok, resource}`, where `resource` is an Erlang
  resource object representing a handle for the poll thread. Otherwise, one of
  the following errors is returned:

  * `{:error, :not_running} - termbox should be initialized before events are
    polled.
  * `{:error, :already_polling}` - `start_polling/1` was previously called and
    has not been since stopped.
  """
  @spec start_polling(pid()) ::
          {:ok, reference()} | {:error, :not_running | :already_polling}
  def start_polling(recipient_pid) when is_pid(recipient_pid) do
    error("NIF start_polling/1 not loaded")
  end

  @doc """
  Cancels a previous call to `start_polling/1` and blocks until polling has
  stopped. The polling loop checks every 10 ms for a stop condition, so calls
  can take up to 10 ms to return.

  This can be useful, for example, if the `start_polling/1` recipient process
  dies and the polling needs to be restarted by another process.

  Returns `:ok` on success and otherwise one of the following errors:

  * `{:error, :not_running} - termbox should be initialized before any polling
    functions are called.
  * `{:error, :not_polling} - polling cannot be stopped because it was already
    stopped or never started.
  """
  @spec stop_polling() :: :ok | {:error, :not_running | :not_polling}
  def stop_polling do
    error("NIF stop_polling/1 not loaded")
  end

  defp error(reason), do: :erlang.nif_error(reason)
end
