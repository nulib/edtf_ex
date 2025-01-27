defmodule EDTF.Parser.Helpers do
  @moduledoc """
  Helper functions for parsing EDTF dates
  """

  import Bitwise

  @qualifier_attributes %{
    ~c"~" => [:approximate],
    ~c"?" => [:uncertain],
    ~c"%" => [:approximate, :uncertain]
  }

  @doc """
  Calculate the appropriate qualifier bitmasks for a given YYYY, MM, or DD. Bits
  are calculated from the left and shifted left to account for the specific
  component.

  - The digits of YYYY are 1, 2, 4, 8
  - The digits of MM are 16, 32
  - The digits of DD are 64, 128

  A full component qualifier (leading `~`, `?`, or `%`) results in the component
  being fully masked (15 for year, 48 for month, or 192 for day). Unspecified digits
  (`X`) flip individual bits.

  A pre-component qualifier results in only that component being masked. A post-
  component qualifier results in that component plus all components to the left
  being masked.

  Example:
    ```elixir
    iex> bitmask("-%02", [value: ~c"200X", sign: ~c"-"], %{}, nil, nil, 0)
    {"-%02", [[value: -2000, attributes: [unspecified: 8]]], %{}}

    iex> bitmask("", [value: ~c"02", pre_qualifier: ~c"%"], %{}, nil, nil, 4)
    {"", [[value: 2, attributes: [approximate: 48, uncertain: 48]]], %{}}

    iex> bitmask("", [value: ~c"02", post_qualifier: ~c"%"], %{}, nil, nil, 4)
    {"", [[value: 2, attributes: [approximate: 63, uncertain: 63]]], %{}}
    ```
  """
  def bitmask(rest, value, context, _line, _offset, shift) do
    qualifier =
      cond do
        Keyword.get(value, :pre_qualifier) -> {:pre, Keyword.get(value, :pre_qualifier)}
        Keyword.get(value, :post_qualifier) -> {:post, Keyword.get(value, :post_qualifier)}
        true -> nil
      end

    {rest,
     [
       bitmask(
         Keyword.get(value, :value),
         Keyword.get(value, :sign, ~c""),
         qualifier,
         shift
       )
     ], context}
  end

  def bitmask(bitstring, sign, nil, shift) do
    {output, mask} =
      bitstring
      |> Enum.with_index()
      |> Enum.reduce({~c"", 0}, fn
        {?X, index}, {output, mask} ->
          char = if output == ~c"0" and shift > 0 and index > 0, do: "1", else: "0"
          {[char | output], mask + 2 ** index}

        {char, _}, {output, mask} ->
          {[char | output], mask}
      end)

    output = Enum.reverse(output)

    {output, mask} =
      {[sign | output]
       |> IO.iodata_to_binary()
       |> String.to_integer(), mask <<< shift}

    case mask do
      0 -> [value: output]
      mask -> [value: output, attributes: [unspecified: mask]]
    end
  end

  def bitmask(bitstring, sign, {qualifier_position, qualifier}, shift) do
    mask = calculate_mask(bitstring, shift, qualifier_position)

    attributes =
      Map.get(@qualifier_attributes, qualifier)
      |> Enum.map(&{&1, mask})

    [
      value: IO.iodata_to_binary([sign | bitstring]) |> String.to_integer(),
      attributes: attributes
    ]
  end

  defp calculate_mask(bitstring, shift, :pre), do: ((1 <<< length(bitstring)) - 1) <<< shift
  defp calculate_mask(bitstring, shift, :post), do: (1 <<< (length(bitstring) + shift)) - 1

  @doc """
  Apply a parsed sign to a parsed integer value.

  Example:
    ```elixir
    iex> apply_sign("", [value: 2000, sign: ~c"-"], %{}, nil, nil)
    {"", [value: -2000], %{}}

    iex> apply_sign("", [value: 2000], %{}, nil, nil)
    {"", [value: 2000], %{}}
    ```
  """
  def apply_sign(rest, value, context, _line, _offset) do
    value = List.flatten(value)

    result =
      case Keyword.get(value, :sign) do
        ~c"-" -> 0 - Keyword.get(value, :value)
        _ -> Keyword.get(value, :value)
      end

    {rest, value |> Keyword.delete(:sign) |> Keyword.put(:value, result), context}
  end

  @doc """
  Apply a parsed qualifier to a single value.

  Example:
    ```elixir
    iex> apply_qualifier("", [value: 2000, qualifier: ~c"%"], %{}, nil, nil)
    {"", [attributes: [approximate: true, uncertain: true], value: 2000], %{}}

    iex> apply_qualifier("", [value: 2000], %{}, nil, nil)
    {"", [attributes: [], value: 2000], %{}}
    ```
  """
  def apply_qualifier(rest, value, context, _line, _offset) do
    qualifier = Keyword.get(value, :qualifier)

    attributes =
      Map.get(@qualifier_attributes, qualifier, [])
      |> Enum.map(&{&1, true})

    {rest, Keyword.delete(value, :qualifier) |> Keyword.put(:attributes, attributes), context}
  end

  @doc """
  Convert a parsed numeric bitstring to an integer

  Example:
    ```elixir
    iex> to_integer("", ~c"4321", %{}, nil, nil)
    {"", [1234], %{}}
  """
  def to_integer(rest, value, context, _line, _offset) do
    {rest, [value |> Enum.reverse() |> to_string() |> String.to_integer()], context}
  end

  @doc """
  Reduce a list of components and bitmasks to a single list of values with
  their mask attributes ORed together.

  Example:
    ```elixir
    iex> reduce("", [
    ...>   [value: 10, attributes: [unspecified: 128]],
    ...>   [value: 1, attributes: [unspecified: 32]],
    ...>   [value: 0, attributes: [unspecified: 5]]
    ...> ], %{}, nil, nil)
    {"", [values: [0, 1, 10], attributes: [unspecified: 165]], %{}}

    iex> reduce("", [
    ...>   [value: 10, attributes: [unspecified: 128]],
    ...>   [value: 1, attributes: [approximate: 48]],
    ...>   [value: 0, attributes: [approximate: 15, uncertain: 15]]
    ...> ], %{}, nil, nil)
    {"", [values: [0, 1, 10], attributes: [unspecified: 128, approximate: 63, uncertain: 15]], %{}}
  """
  def reduce(rest, values, context, _line, _offset) do
    case reduce(Keyword.get(values, :qualifier), Enum.reject(values, &is_tuple/1)) do
      {:error, reason} -> {:error, reason}
      values -> {rest, values, context}
    end
  end

  defp reduce(nil, values) do
    {values, attributes} =
      Enum.reduce(values, {[], []}, fn member, {values_acc, attrs_acc} ->
        value = Keyword.get(member, :value)
        attrs = Keyword.get(member, :attributes, [])
        new_values_acc = [value | values_acc]

        new_attrs_acc =
          Enum.reduce(attrs, attrs_acc, fn {key, attr_value}, acc ->
            Keyword.update(acc, key, attr_value, &(&1 ||| attr_value))
          end)
          |> Enum.reject(fn {_, v} -> v == 0 end)

        {new_values_acc, new_attrs_acc}
      end)

    [values: values, attributes: attributes]
  end

  defp reduce(qualifier, values) do
    if Enum.all?(values, fn v -> Keyword.get(v, :attributes, []) |> length() == 0 end) do
      attributes =
        Map.get(@qualifier_attributes, qualifier, [])
        |> Enum.map(&{&1, true})

      values = Enum.reduce(values, [], fn value, acc -> [Keyword.get(value, :value) | acc] end)

      [values: values, attributes: attributes]
    else
      {:error, "Cannot mix level 0 and level 2 qualifiers"}
    end
  end
end
