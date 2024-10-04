defmodule EDTF.Range do
  @moduledoc """
  Parser for EDTF Ranges
  """

  @matcher ~r"^([^/]+)\.\.([^/]+)$"
  @valid [EDTF.Date]

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    case Regex.run(@matcher, edtf) do
      [_, start, stop] ->
        case {EDTF.parse(start, @valid), EDTF.parse(stop, @valid)} do
          {{:ok, start_date}, {:ok, stop_date}} ->
            {:ok, [start_date, stop_date]}

          _ ->
            EDTF.error()
        end

      _ ->
        EDTF.error()
    end
  end
end
