defmodule EDTF.Humanize.Date do
  @moduledoc """
  Humanize EDTF Date, Year, Decade, Century, and Season types
  """

  @bce_suffix " BCE"
  @months ~w(January February March April May June July August September October November December)
  @seasons %{
    21 => "Spring",
    22 => "Summer",
    23 => "Autumn",
    24 => "Winter",
    25 => "Spring (Northern Hemisphere)",
    26 => "Summer (Northern Hemisphere)",
    27 => "Autumn (Northern Hemisphere)",
    28 => "Winter (Northern Hemisphere)",
    29 => "Spring (Southern Hemisphere)",
    30 => "Summer (Southern Hemisphere)",
    31 => "Autumn (Southern Hemisphere)",
    32 => "Winter (Southern Hemisphere)",
    33 => "Quarter 1",
    34 => "Quarter 2",
    35 => "Quarter 3",
    36 => "Quarter 4",
    37 => "Quadrimester 1",
    38 => "Quadrimester 2",
    39 => "Quadrimester 3",
    40 => "Semestral 1",
    41 => "Semestral 2"
  }

  def humanize(%EDTF.Date{type: type, values: values, attributes: attributes}) do
    humanize(type, values, Enum.into(attributes, %{}))
  end

  defp humanize(:date, values, %{approximate: _v} = attributes) do
    "circa " <> humanize(:date, values, Map.delete(attributes, :approximate))
  end

  defp humanize(:date, values, %{unspecified: 15})
       when length(values) == 1,
       do: "Unknown"

  defp humanize(:date, values, %{unspecified: unspecified} = attributes)
       when unspecified in [8, 12, 14] and length(values) == 1 do
    humanize(:date, values, Map.delete(attributes, :unspecified))
    |> String.replace(~r/(\d+)/, "\\0s")
  end

  defp humanize(:date, _, %{unspecified: _}), do: :original

  defp humanize(:date, values, %{uncertain: true} = attributes),
    do: humanize(:date, values, Map.delete(attributes, :uncertain)) <> "?"

  defp humanize(:date, values, _) do
    case values do
      [year | [month | [day]]] -> "#{Enum.at(@months, month)} #{day}, #{set_era(year)}"
      [year | [month]] -> "#{Enum.at(@months, month)} #{set_era(year)}"
      [year] -> "#{set_era(year)}"
    end
  end

  defp humanize(:season, [year | [season]], _) when year < 0,
    do: Map.get(@seasons, season) <> " #{-year}#{@bce_suffix}"

  defp humanize(:season, [year | [season]], _),
    do: Map.get(@seasons, season) <> " #{year}"

  defp humanize(:year, [value], _), do: set_era(value)

  defp humanize(:decade, [value], _) when value < 0,
    do: "#{-value * 10}s#{@bce_suffix}"

  defp humanize(:decade, [value], _), do: "#{value * 10}s"

  defp humanize(:century, [value], _) when value < 0,
    do: "#{Inflex.ordinalize(-value)} Century#{@bce_suffix}"

  defp humanize(:century, [value], _), do: "#{Inflex.ordinalize(value)} Century"

  defp set_era(year) do
    if year < 0, do: "#{-year}#{@bce_suffix}", else: to_string(year)
  end
end
