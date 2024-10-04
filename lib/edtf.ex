defmodule EDTF do
  alias EDTF.{Date, Interval, List, Range, Set}

  def parse(edtf, include \\ [Interval, List, Range, Set, Date]) do
    case Enum.find(include, & &1.match?(edtf)) do
      nil -> invalid()
      mod -> mod.parse(edtf)
    end
  end

  def invalid, do: {:error, :invalid_format}

  #  defp is(edtf, matcher), do: Regex.match?(@matchers[matcher], edtf)
end
