defmodule EDTF do
  @moduledoc """
  Parse, validate, and humanize EDTF date strings
  """

  alias EDTF.{Aggregate, Date, Interval}

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
  def parse(edtf, include \\ [Interval, Aggregate, Date]) do
    case Enum.find(include, & &1.match?(edtf)) do
      nil -> error()
      mod -> mod.parse(edtf)
    end
  end

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
  Generate an error response
  """
  def error(error \\ :invalid_format), do: {:error, error}

  @doc """
  Identify the open-ended continuation markers on an EDTF date string
  """
  def open_ended(edtf) do
    case Regex.named_captures(~r/^(?<earlier>\.\.)?(?<edtf>.+?)(?<later>\.\.)?$/, edtf) do
      %{"earlier" => "..", "edtf" => result, "later" => ".."} ->
        {result, [{:earlier, true}, {:later, true}]}

      %{"earlier" => "..", "edtf" => result} ->
        {result, [{:earlier, true}, {:later, false}]}

      %{"edtf" => result, "later" => ".."} ->
        {result, [{:earlier, false}, {:later, true}]}

      %{"edtf" => result} ->
        {result, [{:earlier, false}, {:later, false}]}
    end
  end
end
