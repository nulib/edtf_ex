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
    assert EDTF.parse("2020-%06-25?") == {:error, :invalid_format}
  end

  test "parse/2 with validate: false accepts calendar-invalid dates" do
    assert EDTF.parse("1999-02-30") == {:error, :invalid_date}

    assert EDTF.parse("1999-02-30", validate: false) ==
             {:ok, %EDTF.Date{level: 0, type: :date, values: [1999, 1, 30]}}

    # validate: true is the default and still rejects.
    assert EDTF.parse("1999-02-30", validate: true) == {:error, :invalid_date}

    # Bypassing validation does not bypass format checks.
    assert EDTF.parse("bad date!", validate: false) == {:error, :invalid_format}
  end

  test "humanize/2 with validate: false renders calendar-invalid dates" do
    assert EDTF.humanize("1999-02-30") == {:error, :invalid_date}
    assert EDTF.humanize("1999-02-30", validate: false) == "February 30, 1999"
    assert EDTF.humanize("bad date!", validate: false) == {:error, :invalid_format}
  end

  test "to_date_range/1" do
    assert EDTF.to_date_range("2020") == {:ok, {~D[2020-01-01], ~D[2020-12-31]}}
    assert EDTF.to_date_range("bad date!") == {:error, :invalid_format}
  end

  test "rejects unprefixed short-digit years (ISO 8601-2 requires Y prefix or 4-digit form)" do
    assert EDTF.parse("1") == {:error, :invalid_format}
    assert EDTF.humanize("1") == {:error, :invalid_format}
    assert EDTF.validate("1") == {:error, :invalid_format}

    assert EDTF.parse("0001") ==
             {:ok, %EDTF.Date{level: 0, type: :date, values: [1]}}

    assert EDTF.parse("Y20020") ==
             {:ok,
              %EDTF.Date{level: 1, type: :year, values: [20_020], attributes: [significant: nil]}}
  end
end
