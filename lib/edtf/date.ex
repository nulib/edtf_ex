defmodule EDTF.Date do
  @moduledoc """
  Parser for basic EDTF dates, including year, and decade
  """

  defstruct type: :date,
            values: [],
            level: 0,
            attributes: []

  @type edtf_type :: :date | :century | :decade | :year
  @type edtf_attribute ::
          {:unspecified, integer()}
          | {:uncertain, integer() | boolean()}
          | {:approximate, integer() | boolean()}
          | {:significant, integer()}
          | {:earlier, boolean()}
          | {:later, boolean()}

  @type t ::
          %__MODULE__{
            type: edtf_type(),
            values: list(integer() | t() | list(t())),
            level: integer(),
            attributes: list({edtf_attribute(), any()})
          }
          | nil

  def assemble({_, nil}), do: nil

  def assemble({type, value}) when type == :decade or type == :century,
    do: %__MODULE__{
      type: type,
      values: [Keyword.get(value, :value)],
      attributes: Keyword.get(value, :attributes)
    }

  def assemble({:year, value}) do
    attributes = Keyword.get(value, :attributes, [])
    multiplier = 10 ** Keyword.get(attributes, :exponent, 0)
    significant = Keyword.get(attributes, :significant)
    level = if significant, do: 2, else: 1

    value = Keyword.get(value, :value) * multiplier

    %__MODULE__{
      type: :year,
      values: [value],
      attributes: [significant: significant],
      level: level
    }
  end

  def assemble({:date, [:infinity]}), do: %EDTF.Infinity{}

  def assemble({:date, value}) do
    values = Keyword.get(value, :values)

    {type, values} =
      case values do
        [year, month, day] ->
          {:date, [year, month - 1, day]}

        [year, month] ->
          if month > 12, do: {:season, [year, month]}, else: {:date, [year, month - 1]}

        [year] ->
          {:date, [year]}
      end

    %__MODULE__{
      type: type,
      values: values,
      attributes: Keyword.get(value, :attributes)
    }
  end
end
