defmodule EDTF.Level do
  @moduledoc """
  Utility functions to add the correct level to `%EDTF.Date` structs
  """

  def add_level({:error, _} = error), do: error

  def add_level(%EDTF.Aggregate{} = aggregate),
    do: Map.update!(aggregate, :values, &add_level/1)

  def add_level({:ok, value}), do: {:ok, add_level(value)}

  def add_level([]), do: []
  def add_level([value | values]), do: [add_level(value) | add_level(values)]
  def add_level(%{level: level} = result) when level > 0, do: result
  def add_level(result), do: Map.put(result, :level, determine_level(result))

  defp determine_level(%EDTF.Date{type: :century}), do: 1
  defp determine_level(%EDTF.Date{type: :decade}), do: 1

  defp determine_level(%EDTF.Date{type: :season, values: [_, s]}) do
    if s > 24, do: 2, else: 1
  end

  defp determine_level(%EDTF.Date{attributes: attrs, level: level, values: values}) do
    if Enum.empty?(attrs),
      do: level,
      else: attrs |> Enum.into(%{}) |> calculate_level(values)
  end

  defp calculate_level(%{unspecified: bits}, values) when length(values) == 1 do
    if Enum.member?([15, 14, 12, 8], bits), do: 1, else: 2
  end

  defp calculate_level(%{unspecified: bits}, values) when length(values) == 2 do
    if Enum.member?([63, 62, 60, 56, 48, 32], bits), do: 1, else: 2
  end

  defp calculate_level(%{unspecified: bits}, values) when length(values) == 3 do
    if Enum.member?([255, 254, 252, 248, 240, 224, 192, 128], bits), do: 1, else: 2
  end

  defp calculate_level(%{approximate: v}, _) when is_boolean(v), do: 1
  defp calculate_level(%{approximate: _v}, _), do: 2
  defp calculate_level(%{uncertain: v}, _) when is_boolean(v), do: 1
  defp calculate_level(%{uncertain: _v}, _), do: 2
end
