defmodule EDTF do
  alias EDTF.{Date, Interval, List, Range, Set}

  def parse(edtf, include \\ [Interval, List, Range, Set, Date]) do
    case Enum.find(include, & &1.match?(edtf)) do
      nil -> invalid(edtf)
      mod -> mod.parse(edtf)
    end
  end

  def invalid(edtf), do: {:error, "Invalid EDTF input: " <> edtf}

  #  defp is(edtf, matcher), do: Regex.match?(@matchers[matcher], edtf)
end
