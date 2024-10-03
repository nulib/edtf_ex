defmodule EDTF.Date do
  @matcher ~r/^Y?-?[\dX]+(?:E\d+)?(?:-[\dX]{2})?(?:-[\dX]{2})?$/
  @attribute_matchers [
    approximate: ~r/^(.+)[%~]$/,
    uncertain: ~r/^(.+)%$/
  ]

  defstruct type: :date,
            values: [],
            level: 0,
            attributes: []

  @type edtf_type :: :date | :year | :decade | :season
  @type edtf_attribute :: :unspecified | :approximate | :earlier | :later
  @type t ::
          %__MODULE__{
            type: edtf_type(),
            values: list(integer() | t() | list(t())),
            level: integer(),
            attributes: list(edtf_attribute())
          }
          | nil

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    if match?(edtf),
      do: {:ok, %__MODULE__{type: :date, values: [edtf], level: 0}},
      else: EDTF.invalid(edtf)
  end
end
