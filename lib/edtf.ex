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
end
