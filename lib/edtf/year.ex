defmodule EDTF.Year do
  @moduledoc """
  Parser for EDTF Level 1 Years
  """

  @matcher ~r/^Y(?<year>-?\d+)(?:E(?<exponent>\d+))?$/

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    Regex.named_captures(@matcher, edtf)
    |> calculate()
    |> case do
      :error -> EDTF.error()
      result -> result
    end
  end

  defp calculate(%{"year" => year, "exponent" => ""}),
    do: {:ok, %EDTF.Date{type: :year, values: [String.to_integer(year)], level: 1}}

  defp calculate(%{"year" => year, "exponent" => exponent}) do
    {:ok,
     %EDTF.Date{
       type: :year,
       values: [String.to_integer(year) * 10 ** String.to_integer(exponent)],
       level: 2
     }}
  end

  defp calculate(_), do: :error
end
