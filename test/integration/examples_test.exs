defmodule ExTermbox.Integration.ExamplesTest do
  @moduledoc """
  This test ensures that the examples can all be started and quit.

  Because the examples use the real termbox bindings and start named processes,
  these tests should be run separately from the unit tests.
  """

  use ExUnit.Case, async: false

  alias ExTermbox.{Event, EventManager}

  @examples_root Path.join(Path.dirname(__ENV__.file), "../../examples")
  @examples Path.wildcard("#{@examples_root}/*.exs")

  setup do
    on_exit(fn ->
      event_mgr = event_manager()

      if is_pid(event_mgr) do
        :ok = GenServer.stop(event_mgr, :normal)
      end
    end)

    :ok
  end

  @tag :integration
  test "at least one example is found" do
    assert [_ | _] = @examples
  end

  for example_path <- @examples do
    @example_path example_path
    @example_basename Path.basename(example_path)

    @tag :integration
    test "running example '#{@example_basename}' succeeds" do
      pid = spawn(fn -> Code.eval_file(@example_path) end)
      ref = Process.monitor(pid)

      # TODO: Try tracing call to Bindings.present/0 and wait for that
      Process.sleep(500)

      assert Process.alive?(pid)
      assert is_pid(event_manager())

      simulate_event(event_manager(), %Event{type: 1, ch: ?q})

      assert_receive({:DOWN, ^ref, :process, ^pid, :normal}, 1_000)
      refute Process.alive?(pid)
    end
  end

  def simulate_event(pid, event), do: send(pid, {:event, event})

  def event_manager, do: Process.whereis(EventManager)
end
