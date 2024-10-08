defmodule EDTF.Date do
  @moduledoc """
  Parser for basic EDTF dates, including year, and decade
  """

  alias EDTF.{Season, Year}

  @matcher ~r/^Y?[~%?]?-?[\dX]+(?:E\d+)?(?:S\d+)?(?:-[~%?]?[\dX]{2})?(?:-[~%?]?[\dX]{2})?[~%?]?$/
  @subtypes [Year, Season]

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

  def match?(edtf), do: Regex.match?(@matcher, edtf)

  def parse(edtf) do
    case Enum.find(@subtypes, & &1.match?(edtf)) do
      nil -> parse_date(edtf)
      mod -> mod.parse(edtf)
    end
  end

  defp parse_date(edtf) do
    {edtf, attributes} = get_attributes(edtf)

    parse_date(edtf, attributes)
    |> case do
      :error -> EDTF.error()
      result -> result
    end
  end

  defp parse_date(<<"-", val::binary-size(2)>>, attributes) do
    {:ok,
     %__MODULE__{type: :century, values: [0 - String.to_integer(val)], attributes: attributes}}
  end

  defp parse_date(<<val::binary-size(2)>>, attributes) do
    {:ok, %__MODULE__{type: :century, values: [String.to_integer(val)], attributes: attributes}}
  end

  defp parse_date(<<"-", val::binary-size(3)>>, attributes) do
    {:ok,
     %__MODULE__{type: :decade, values: [0 - String.to_integer(val)], attributes: attributes}}
  end

  defp parse_date(<<val::binary-size(3)>>, attributes) do
    {:ok, %__MODULE__{type: :decade, values: [String.to_integer(val)], attributes: attributes}}
  end

  defp parse_date(edtf, attributes) do
    {edtf, masks} =
      bitmask(edtf)

    [_, sign, edtf] = Regex.run(~r/^(-?)(.+)$/, edtf)

    {edtf, specificity} =
      case String.length(edtf) do
        4 -> {"#{edtf}-01-01", :year}
        7 -> {"#{edtf}-01", :month}
        _ -> {edtf, :day}
      end

    case Elixir.Date.from_iso8601(sign <> edtf) do
      {:ok, %Date{year: year, month: month, day: day}} ->
        [year, month - 1, day] |> process_result(specificity, masks, attributes)

      {:error, _} ->
        :error
    end
  end

  defp process_result(values, specificity, masks, attributes) do
    values =
      case specificity do
        :day -> values
        :month -> Enum.take(values, 2)
        :year -> Enum.take(values, 1)
      end

    attributes = Keyword.merge(attributes, masks)

    {:ok,
     %__MODULE__{
       values: values,
       attributes: attributes
     }}
  end

  defp bitmask(edtf) do
    {str, _, attrs} =
      edtf
      |> String.graphemes()
      |> Enum.reduce(
        {"", 1, [unspecified: 0, approximate: 0, uncertain: 0]},
        fn char, {str, bits, attrs} ->
          case char do
            "X" ->
              {str <> "0", bits * 2, add_bits(attrs, :unspecified, bits)}

            "~" ->
              {str, bits, add_bits(attrs, :approximate, bits)}

            "?" ->
              {str, bits, add_bits(attrs, :uncertain, bits)}

            "%" ->
              {str, bits, add_bits(attrs, :approximate, bits) |> add_bits(:uncertain, bits)}

            "-" ->
              {str <> "-", bits, attrs}

            d ->
              {str <> d, bits * 2, attrs}
          end
        end
      )

    {str
     |> nonzero_month_and_day(), Keyword.reject(attrs, fn {_, v} -> v == 0 end)}
  end

  defp add_bits(attrs, attr, bits) do
    bits =
      cond do
        # unspecified can exist in any place
        attr == :unspecified -> bits
        # approximate or uncertain year (XXXX-mm-dd)
        bits < 15 -> 15
        # approximate or uncertain month (yyyy-XX-dd)
        bits < 48 -> 48
        # approximate or uncertain day (yyyy-mm-XX)
        bits < 192 -> 192
      end

    Keyword.update!(attrs, attr, fn v -> v + bits end)
  end

  defp nonzero_month_and_day(str), do: String.replace(str, "-00", "-01")

  defp get_attributes(edtf) do
    case Regex.named_captures(~r/^(?<edtf>.+?)(?<attr>[~%?])?$/, edtf) do
      %{"edtf" => result, "attr" => ""} ->
        {result, []}

      %{"edtf" => result, "attr" => "~"} ->
        {result, [{:approximate, true}]}

      %{"edtf" => result, "attr" => "%"} ->
        {result, [{:approximate, true}, {:uncertain, true}]}

      %{"edtf" => result, "attr" => "?"} ->
        {result, [{:uncertain, true}]}
    end
  end
end
