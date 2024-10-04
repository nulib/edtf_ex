defmodule EDTF.Season do
  @moduledoc """
  Parser for EDTF Seasons
  """

  @matcher ~r/^(?<year>-?\d{4})-(?<season>\d{2})$/
  @seasons ~w(21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41)

  def match?(edtf) do
    case Regex.named_captures(@matcher, edtf) do
      nil -> false
      %{"season" => season} -> Enum.member?(@seasons, season)
    end
  end

  def parse(edtf) do
    case Regex.named_captures(@matcher, edtf) do
      nil ->
        EDTF.error()

      %{"year" => year, "season" => season} ->
        {:ok,
         %EDTF.Date{
           type: :season,
           values: [String.to_integer(year), String.to_integer(season)],
           level: 2
         }}
    end
  end
end
