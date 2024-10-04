defmodule EDTF.Date do
  @moduledoc """
  Parser for basic EDTF dates, including year, and decade
  """

  alias EDTF.{Season, Year}

  @matcher ~r/^Y?-?[\dX]+(?:E\d+)?(?:-[\dX]{2})?(?:-[\dX]{2})?[~%?]?$/
  @subtypes [Year, Season]

  defstruct type: :date,
            values: [],
            level: 0,
            attributes: []

  @type edtf_type :: :date | :century | :decade | :year
  @type edtf_attribute ::
          {:unspecified, integer()}
          | {:uncertain, boolean()}
          | {:approximate, boolean()}
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

    case edtf do
      <<"-", val::binary-size(2)>> -> {:century, [0 - String.to_integer(val)], 0}
      <<val::binary-size(2)>> -> {:century, [String.to_integer(val)], 0}
      <<"-", val::binary-size(3)>> -> {:decade, [0 - String.to_integer(val)], 2}
      <<val::binary-size(3)>> -> {:decade, [String.to_integer(val)], 2}
      other -> other
    end
    |> case do
      {type, values, level} ->
        {:ok, %__MODULE__{type: type, values: values, level: level, attributes: attributes}}

      other ->
        parse_iso8601(other, attributes)
    end
    |> finalize(edtf)
  end

  defp finalize(:error, _), do: EDTF.error()
  defp finalize({:ok, result}, edtf), do: {:ok, %__MODULE__{result | level: level(edtf)}}

  defp parse_iso8601(<<"-", year::binary-size(4)>>, attributes),
    do: parse_iso8601("-" <> year <> "-01-01", attributes, :year)

  defp parse_iso8601(<<year::binary-size(4)>>, attributes),
    do: parse_iso8601(year <> "-01-01", attributes, :year)

  defp parse_iso8601(<<"-", year::binary-size(4), "-", month::binary-size(2)>>, attributes),
    do: parse_iso8601("-" <> year <> "-" <> month <> "-01", attributes, :month)

  defp parse_iso8601(<<year::binary-size(4), "-", month::binary-size(2)>>, attributes),
    do: parse_iso8601(year <> "-" <> month <> "-01", attributes, :month)

  defp parse_iso8601(edtf, attributes, specificity \\ :day) do
    {edtf, mask} = unspecified(edtf)

    case Elixir.Date.from_iso8601(edtf) do
      {:ok, %Date{year: year, month: month, day: day}} ->
        [year, month - 1, day] |> process_result(specificity, mask, attributes)

      {:error, _} ->
        :error
    end
  end

  defp process_result(values, specificity, mask, attributes) do
    values =
      case specificity do
        :day -> values
        :month -> Enum.take(values, 2)
        :year -> Enum.take(values, 1)
      end

    attributes = if mask > 0, do: [{:unspecified, mask} | attributes], else: attributes

    {:ok,
     %__MODULE__{
       values: values,
       attributes: attributes
     }}
  end

  defp unspecified(<<"-", edtf::binary>>) do
    {edtf, mask} = unspecified(edtf)
    {"-#{edtf}", mask}
  end

  defp unspecified(edtf) do
    new_x = fn
      {"X", 5} -> {"1", 2 ** 5}
      {"X", 7} -> {"1", 2 ** 7}
      {"X", p} -> {"0", 2 ** p}
      {c, _} -> {c, 0}
    end

    {str, mask} =
      edtf
      |> String.graphemes()
      |> Enum.reject(&(&1 == "-"))
      |> Enum.with_index()
      |> Enum.map(new_x)
      |> Enum.reduce({"", 0}, fn {char, bits}, {str, mask} ->
        {str <> char, mask + bits}
      end)

    {str
     |> reassemble()
     |> nonzero_month_and_day(), mask}
  end

  defp level(edtf) do
    cond do
      Regex.match?(~r/^\d{2}X{2}$/, edtf) -> 1
      Regex.match?(~r/^\d{3}X$/, edtf) -> 1
      Regex.match?(~r/^\d{4}-XX$/, edtf) -> 1
      Regex.match?(~r/^\d{4}-\d{2}-XX$/, edtf) -> 1
      Regex.match?(~r/^\d{4}-XX-XX$/, edtf) -> 1
      Regex.match?(~r/X/, edtf) -> 2
      true -> 0
    end
  end

  defp reassemble(<<year::binary-size(4), month::binary-size(2), day::binary-size(2)>>),
    do: [year, month, day] |> Enum.join("-")

  defp nonzero_month_and_day(str), do: String.replace(str, "-00", "-01")

  defp get_attributes(edtf) do
    case Regex.named_captures(~r/^(?<edtf>.+?)(?<attr>[~%?])?$/, edtf) do
      %{"edtf" => result, "attr" => ""} -> {result, []}
      %{"edtf" => result, "attr" => "~"} -> {result, [{:approximate, true}]}
      %{"edtf" => result, "attr" => "%"} -> {result, [{:approximate, true}, {:uncertain, true}]}
      %{"edtf" => result, "attr" => "?"} -> {result, [{:uncertain, true}]}
    end
  end
end
