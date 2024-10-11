defmodule EDTF.Humanize do
  @moduledoc """
  Convert EDTF dates to human readable form
  """

  alias EDTF.Humanize

  def humanize({:ok, value}), do: humanize(value)
  def humanize({:error, _} = arg), do: arg

  def humanize(nil), do: "Unknown"

  def humanize(%EDTF.Interval{start: start_date, end: end_date}) do
    case [start_date, end_date] do
      [value, %EDTF.Infinity{}] -> "from #{humanize(value)}"
      [%EDTF.Infinity{}, value] -> "before #{humanize(value)}"
      values -> values |> Enum.map_join(" to ", &humanize/1)
    end
  end

  def humanize(%EDTF.Date{type: :season} = input), do: Humanize.Date.humanize(input)
  def humanize(%EDTF.Date{type: :year} = input), do: Humanize.Date.humanize(input)
  def humanize(%EDTF.Date{type: :decade} = input), do: Humanize.Date.humanize(input)
  def humanize(%EDTF.Date{type: :century} = input), do: Humanize.Date.humanize(input)
  def humanize(%EDTF.Aggregate{} = input), do: Humanize.Aggregate.humanize(input)
  def humanize(%EDTF.Continuation{} = input), do: Humanize.Aggregate.humanize(input)
  def humanize(%EDTF.Date{} = input), do: Humanize.Date.humanize(input)
end
