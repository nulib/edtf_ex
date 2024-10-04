defmodule EDTF.List do
  @matcher ~r/^\{(.+)\}$/
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
        Regex.split(~r/\s*,\s*/, dates)
        |> Enum.reduce_while([], fn date, acc ->
          case EDTF.parse(date, @valid) do
            {:ok, parsed} -> {:cont, [parsed | acc]}
            {:error, _error} -> {:halt, :error}
          end
        end)
        |> case do
          :error -> EDTF.invalid()
          values -> %__MODULE__{values: Enum.reverse(values), level: 2}
        end

      _ ->
        EDTF.invalid()
    end
  end
end
