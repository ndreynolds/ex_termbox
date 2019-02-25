defmodule EventViewer do
  @moduledoc """
  A sample application that shows debug information about terminal events. These
  can be click, resize or key press events.
  """

  alias ExTermbox.Bindings, as: Termbox
  alias ExTermbox.{Cell, Constants, EventManager, Event, Position}

  def run do
    :ok = Termbox.init()
    {:ok, _} = Termbox.select_input_mode(Constants.input_mode(:esc_with_mouse))
    {:ok, _pid} = EventManager.start_link()
    :ok = EventManager.subscribe(self())

    render_header()
    Termbox.present()
    loop()
  end

  def loop do
    receive do
      {:event, %Event{ch: ?q}} ->
        :ok = EventManager.stop()
        :ok = Termbox.shutdown()

      {:event, %Event{} = event} ->
        Termbox.clear()
        render_header()
        render_event(event)
        Termbox.present()
        loop()
    end
  end

  def render_header do
    render_lines(
      [
        'ExTermbox Event Viewer',
        '',
        '(Click, resize, or press a key to see event diagnostics. <q> to quit.)'
      ],
      0
    )
  end

  def render_event(%Event{
        type: type,
        mod: mod,
        key: key,
        ch: ch,
        w: w,
        h: h,
        x: x,
        y: y
      }) do
    type_name = reverse_lookup(Constants.event_types(), type)

    key_name =
      if key != 0,
        do: reverse_lookup(Constants.keys(), key),
        else: :none

    render_lines(
      [
        '  Type: ' ++ format(type) ++ ' ' ++ format(type_name),
        '   Mod: ' ++ format(mod),
        '   Key: ' ++ format(key) ++ ' ' ++ format(key_name),
        '  Char: ' ++ format(ch) ++ ' ' ++ format(<<ch::utf8>>),
        ' Width: ' ++ format(w),
        'Height: ' ++ format(h),
        '     X: ' ++ format(x),
        '     Y: ' ++ format(y)
      ],
      4
    )
  end

  defp render_lines(lines, y_origin) do
    for {line, y} <- Enum.with_index(lines, y_origin), do: render_line(line, y)
  end

  defp render_line(text, y) do
    for {ch, x} <- Enum.with_index(text) do
      :ok = Termbox.put_cell(%Cell{position: %Position{x: x, y: y}, ch: ch})
    end
  end

  defp format(value) do
    value |> inspect() |> to_charlist()
  end

  def reverse_lookup(map, val) do
    map |> Enum.find(fn {_, v} -> v == val end) |> elem(0)
  end
end

EventViewer.run()
