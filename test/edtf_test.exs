defmodule EDTFTest do
  use ExUnit.Case

  import ExUnit.DocTest

  doctest EDTF, import: true

  test "validate/1" do
    assert EDTF.validate("2020") == {:ok, "2020"}
    assert EDTF.validate("bad date!") == {:error, :invalid_format}
  end

  test "parse/1" do
    assert EDTF.parse("2020") == {:ok, %EDTF.Date{level: 0, values: [2020]}}
    assert EDTF.parse("bad date!") == {:error, :invalid_format}
  end
end
