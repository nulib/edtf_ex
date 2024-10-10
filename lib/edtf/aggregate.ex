defmodule EDTF.Aggregate do
  @moduledoc """
  Parser for EDTF Lists and Sets
  """

  defstruct type: nil, values: [], level: 2, earlier: false, later: false

  @type t :: %__MODULE__{
          type: :list | :set,
          values: list(EDTF.Date.t()),
          level: integer(),
          earlier: boolean(),
          later: boolean()
        }

  def assemble({:list, value}), do: %__MODULE__{assemble(value) | type: :list}
  def assemble({:set, value}), do: %__MODULE__{assemble(value) | type: :set}

  def assemble(value) do
    dates =
      Keyword.get(value, :dates, [])
      |> Enum.map(fn
        [{:interval, _}] = v -> EDTF.Interval.assemble(v)
        v -> EDTF.Date.assemble({:date, v})
      end)

    %__MODULE__{
      values: dates,
      earlier: Keyword.get(value, :earlier, false),
      later: Keyword.get(value, :later, false)
    }
  end
end
