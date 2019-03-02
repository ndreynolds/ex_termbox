defmodule ExTermbox.Integration.BindingsTest do
  use ExUnit.Case, async: false

  alias ExTermbox.Bindings

  setup do
    on_exit(fn ->
      _ = Bindings.stop_polling()
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

  describe "start_polling/1" do
    @tag :integration
    test "returns an error if not running" do
      assert {:error, :not_running} = Bindings.start_polling(self())
    end

    @tag :integration
    test "returns an error if already polling" do
      :ok = Bindings.init()

      assert {:ok, _resource} = Bindings.start_polling(self())
      assert {:error, :already_polling} = Bindings.start_polling(self())

      :ok = Bindings.stop_polling()

      assert {:ok, _resource} = Bindings.start_polling(self())
    end
  end

  describe "stop_polling/0" do
    @tag :integration
    test "cancels the previous start_polling/1 call" do
      :ok = Bindings.init()
      {:ok, _resource} = Bindings.start_polling(self())

      assert :ok = Bindings.stop_polling()
    end

    @tag :integration
    test "returns an error if not running" do
      assert {:error, :not_running} = Bindings.start_polling(self())
    end

    @tag :integration
    test "returns an error if not polling" do
      :ok = Bindings.init()

      {:error, :not_polling} = Bindings.stop_polling()
    end
  end
end
