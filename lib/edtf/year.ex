defmodule EDTF.Year do
  @moduledoc """
  Parser for EDTF Level 1 Years
  """

  @matcher ~r/^Y(?<year>-?\d+)(?:E(?<exponent>\d+))?(?:S(?<significant>\d+))?$/

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    Regex.named_captures(@matcher, edtf)
    |> calculate()
    |> case do
      :error -> EDTF.error()
      result -> result
    end
  end

  defp calculate(%{"year" => year, "exponent" => "", "significant" => significant}),
    do:
      {:ok,
       %EDTF.Date{type: :year, values: [String.to_integer(year)], level: 1}
       |> add_significance(significant)}

  defp calculate(%{"year" => year, "exponent" => exponent, "significant" => significant}) do
    {:ok,
     %EDTF.Date{
       type: :year,
       values: [String.to_integer(year) * 10 ** String.to_integer(exponent)],
       level: 2
     }
     |> add_significance(significant)}
  end

  defp calculate(_), do: :error

  defp add_significance(result, ""), do: result

  defp add_significance(result, v) do
    %EDTF.Date{result | level: 2, attributes: [{:significant, String.to_integer(v)}]}
  end
end
