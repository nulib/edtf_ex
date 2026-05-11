defmodule EDTF do
  @moduledoc """
  Parse, validate, and humanize EDTF date strings
  """

  alias EDTF.{Aggregate, Date, Interval, Level}

  @doc """
  Parse an EDTF date string

  Example:
    ```elixir
    iex> parse("1999-06-10")
    {:ok, %EDTF.Date{level: 0, type: :date, values: [1999, 5, 10]}}

    iex> parse("bad date!")
    {:error, :invalid_format}
    ```
  """
  def parse(edtf) do
    case EDTF.Parser.parse(edtf) do
      {:ok, [result], _, _, _, _} -> {:ok, assemble(result) |> Level.add_level()}
      {:error, _, _, _, _, _} -> {:error, :invalid_format}
    end
  end

  defp assemble({:date, _} = result), do: Date.assemble(result)
  defp assemble({:year, _} = result), do: Date.assemble(result)
  defp assemble({:decade, _} = result), do: Date.assemble(result)
  defp assemble({:century, _} = result), do: Date.assemble(result)
  defp assemble({:interval, _} = result), do: Interval.assemble(result)
  defp assemble({:set, _} = result), do: Aggregate.assemble(result)
  defp assemble({:list, _} = result), do: Aggregate.assemble(result)

  @doc """
  Validate an EDTF date string

  Example:
    ```elixir
    iex> validate("1999-06-10")
    {:ok, "1999-06-10"}

    iex> validate("bad date!")
    {:error, :invalid_format}
    ```
  """
  def validate(edtf) do
    case parse(edtf) do
      {:ok, _} -> {:ok, edtf}
      error -> error
    end
  end

  @doc """
  Humanize an EDTF date string

  Example:
    ```elixir
    iex> humanize("1999-06-10")
    "June 10, 1999"

    iex> humanize("bad date!")
    {:error, :invalid_format}
    ```
  """
  def humanize(edtf) do
    case edtf |> parse() |> EDTF.Humanize.humanize() do
      :original -> edtf
      other -> other
    end
  end

  @doc """
  Convert an EDTF date string (or a previously parsed `EDTF.Date`,
  `EDTF.Interval`, or `EDTF.Aggregate` struct) into a `{start_date, end_date}`
  tuple of `Date.t()` values.

  Explicitly open inputs (`/..`, `../`, aggregate `..`-continuations) produce
  `:unbounded` on that side. Inputs with an unknown bound (`1985/`, `/1985`)
  produce `:unknown`. Qualifiers (`~`, `?`, `%`) are ignored; the range uses
  the nominal date. Unspecified-digit suffixes (e.g. `19XX`) expand to their
  full span. See `EDTF.DateRange` for the full semantics.

  Returns `{:error, :invalid_format}` when parsing fails, `{:error, :out_of_range}`
  when `Date.new/3` itself rejects a value, and `{:error, :unsupported}` for
  shapes the converter declines (e.g. fully-unknown year `XXXX` or non-suffix
  unspecified digits like `X9X2`).

  Example:
    ```elixir
    iex> to_date_range("1999-06-10")
    {:ok, {~D[1999-06-10], ~D[1999-06-10]}}

    iex> to_date_range("1985/..")
    {:ok, {~D[1985-01-01], :unbounded}}

    iex> to_date_range("19XX")
    {:ok, {~D[1900-01-01], ~D[1999-12-31]}}

    iex> to_date_range("[1667, 1668, 1670..1672]")
    {:ok, {~D[1667-01-01], ~D[1672-12-31]}}

    iex> to_date_range("bad date!")
    {:error, :invalid_format}
    ```
  """
  def to_date_range(edtf) when is_binary(edtf) do
    edtf |> parse() |> EDTF.DateRange.to_date_range()
  end

  def to_date_range(edtf), do: EDTF.DateRange.to_date_range(edtf)
end
