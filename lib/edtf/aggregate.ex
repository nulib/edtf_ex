defmodule EDTF.Aggregate do
  @moduledoc """
  Parser for EDTF Lists and Sets
  """

  @matchers list: ~r/^\{(.+)\}$/, set: ~r/^\[(.+)\]$/

  @valid [EDTF.Date, EDTF.Range]

  defstruct type: nil, values: [], level: 2, earlier: false, later: false

  @type t :: %__MODULE__{
          type: :list | :set,
          values: list(EDTF.Date.t()),
          level: integer(),
          earlier: boolean(),
          later: boolean()
        }

  def match?(edtf), do: Enum.any?(@matchers, fn {_, re} -> Regex.match?(re, edtf) end)

  def parse(edtf) do
    case Enum.find(@matchers, fn {_, re} -> Regex.match?(re, edtf) end) do
      nil ->
        EDTF.error()

      {type, re} ->
        [_, dates] = Regex.run(re, edtf)
        {dates, attributes} = EDTF.open_ended(dates)

        Regex.split(~r/\s*,\s*/, dates)
        |> Enum.reduce_while([], &reducer/2)
        |> finalize(type, attributes)
    end
  end

  defp reducer(date, acc) do
    case EDTF.parse(date, @valid) do
      {:ok, parsed} -> {:cont, [parsed | acc]}
      {:error, _error} -> {:halt, :error}
    end
  end

  defp finalize(:error, _, _), do: EDTF.error()

  defp finalize(values, type, attributes),
    do: %__MODULE__{
      type: type,
      values: Enum.reverse(values),
      earlier: attributes[:earlier],
      later: attributes[:later],
      level: 2
    }
end
