defmodule EDTF.ErrorTest do
  use ExUnit.Case

  test "edge cases" do
    refute EDTF.Infinity.match?("")
    assert EDTF.Infinity.parse("") == {:error, :invalid_format}
  end

  test "parser errors" do
    assert EDTF.Date.parse("bad!") == {:error, :invalid_format}
    assert EDTF.Aggregate.parse("bad!") == {:error, :invalid_format}
    assert EDTF.Aggregate.parse("[bad!]") == {:error, :invalid_format}
    assert EDTF.Range.parse("bad!") == {:error, :invalid_format}
    assert EDTF.Range.parse("1000..bad!") == {:error, :invalid_format}
    assert EDTF.Interval.parse("bad!") == {:error, :invalid_format}
    assert EDTF.Interval.parse("2024/bad!") == {:error, :invalid_format}
    assert EDTF.Season.parse("2024-bad!") == {:error, :invalid_format}
    assert EDTF.Year.parse("bad!") == {:error, :invalid_format}
  end
end
