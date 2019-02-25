defmodule ExTermbox.Integration.BindingsTest do
  use ExUnit.Case, async: false

  alias ExTermbox.Bindings

  setup do
    on_exit(fn ->
      _ = Bindings.cancel_poll_event()
      _ = Bindings.shutdown()
    end)

    :ok
  end

  describe "init/0" do
    @tag :integration
    test "returns an error if already running" do
      assert :ok = Bindings.init()
      assert {:error, :already_running} = Bindings.init()

      assert :ok = Bindings.shutdown()
      assert :ok = Bindings.init()
    end
  end

  describe "shutdown/0" do
    @tag :integration
    test "returns :ok if sucessfully shutdown" do
      :ok = Bindings.init()

      assert :ok = Bindings.shutdown()
    end

    @tag :integration
    test "returns an error if not running" do
      assert {:error, :not_running} = Bindings.shutdown()
    end
  end

  describe "poll_event/1" do
    @tag :integration
    test "returns an error if not running" do
      assert {:error, :not_running} = Bindings.poll_event(self())
    end

    @tag :integration
    test "returns an error if already polling" do
      :ok = Bindings.init()

      assert {:ok, _resource} = Bindings.poll_event(self())
      assert {:error, :already_polling} = Bindings.poll_event(self())

      :ok = Bindings.cancel_poll_event()

      assert {:ok, _resource} = Bindings.poll_event(self())
    end
  end

  describe "cancel_poll_event/0" do
    @tag :integration
    test "cancels the previous poll event call" do
      :ok = Bindings.init()
      {:ok, _resource} = Bindings.poll_event(self())

      assert :ok = Bindings.cancel_poll_event()
    end

    @tag :integration
    test "returns an error if not running" do
      assert {:error, :not_running} = Bindings.poll_event(self())
    end

    @tag :integration
    test "returns an error if not polling" do
      :ok = Bindings.init()

      {:error, :not_polling} = Bindings.cancel_poll_event()
    end
  end
end
