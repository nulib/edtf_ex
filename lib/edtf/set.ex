defmodule EDTF.Set do
  @moduledoc """
  Parser for EDTF Sets
  """

  @matcher ~r/^\[(.+)\]$/
  @valid [EDTF.Date, EDTF.Range]

  defstruct values: [], level: 2, earlier: false, later: false

  @type t :: %__MODULE__{
          values: list(EDTF.Date.t()),
          level: integer(),
          earlier: boolean(),
          later: boolean()
        }

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    case Regex.run(@matcher, edtf) do
      [_, dates] ->
        {dates, attributes} = EDTF.open_ended(dates)

        Regex.split(~r/\s*,\s*/, dates)
        |> Enum.reduce_while([], &reducer/2)
        |> finalize(attributes)

      _ ->
        EDTF.error()
    end
  end

  defp reducer(date, acc) do
    case EDTF.parse(date, @valid) do
      {:ok, parsed} -> {:cont, [parsed | acc]}
      {:error, _error} -> {:halt, :error}
    end
  end

  defp finalize(:error, _), do: EDTF.error()

  defp finalize(values, attributes),
    do: %__MODULE__{
      values: Enum.reverse(values),
      earlier: attributes[:earlier],
      later: attributes[:later],
      level: 2
    }
end
