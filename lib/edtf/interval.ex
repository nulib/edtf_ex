defmodule EDTF.Interval do
  @matcher ~r"^([^/]+)?/([^/]+)?$"
  @valid [EDTF.Date, EDTF.Infinity]

  defstruct start: nil,
            end: nil,
            level: 1

  @type t :: %__MODULE__{
          start: EDTF.Date.t() | nil,
          end: EDTF.Date.t() | nil,
          level: integer()
        }

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    case Regex.run(@matcher, edtf) do
      [_ | values] ->
        values
        |> Enum.reduce_while([], fn
          "", acc ->
            {:cont, [nil | acc]}

          date, acc ->
            case EDTF.parse(date, @valid) do
              {:ok, parsed} -> {:cont, [parsed | acc]}
              {:error, _error} -> {:halt, :error}
            end
        end)
        |> case do
          :error -> EDTF.invalid()
          values -> Enum.reverse(values) |> module()
        end

      _ ->
        EDTF.invalid()
    end
  end

  defp module([start | [stop]]), do: %__MODULE__{start: start, end: stop, level: 1}
  defp module([v]), do: module([v, nil])
end
