defmodule EDTF.CalendarValidationTest do
  use ExUnit.Case

  describe "parse/1 rejects impossible calendar dates" do
    test "day out of range for the month" do
      assert EDTF.parse("1999-02-30") == {:error, :invalid_date}
      assert EDTF.parse("2021-04-31") == {:error, :invalid_date}
      assert EDTF.parse("2021-06-31") == {:error, :invalid_date}
    end

    test "February 29 on a non-leap year" do
      assert EDTF.parse("1999-02-29") == {:error, :invalid_date}
      assert EDTF.parse("1900-02-29") == {:error, :invalid_date}
    end

    test "month out of range" do
      assert EDTF.parse("1999-00-15") == {:error, :invalid_date}
      assert EDTF.parse("1999-13-01") == {:error, :invalid_date}
      assert EDTF.parse("1999-00") == {:error, :invalid_date}
    end

    test "qualified but concrete impossible dates are still rejected" do
      assert EDTF.parse("1999-02-30?") == {:error, :invalid_date}
      assert EDTF.parse("1999-02-30~") == {:error, :invalid_date}
      assert EDTF.parse("1999-02-30%") == {:error, :invalid_date}
    end

    test "invalid dates inside intervals" do
      assert EDTF.parse("1999-02-30/2000-01-01") == {:error, :invalid_date}
      assert EDTF.parse("2000-01-01/1999-02-30") == {:error, :invalid_date}
    end

    test "invalid dates inside lists and sets" do
      assert EDTF.parse("{1999-01-01,1999-02-30}") == {:error, :invalid_date}
      assert EDTF.parse("[1999-02-30,2000-01-01]") == {:error, :invalid_date}
    end
  end

  describe "parse/1 rejects out-of-range season codes" do
    test "codes below the season range" do
      assert EDTF.parse("1999-13") == {:error, :invalid_date}
      assert EDTF.parse("1999-20") == {:error, :invalid_date}
    end

    test "codes above the season range" do
      assert EDTF.parse("1999-42") == {:error, :invalid_date}
    end

    test "valid season codes are accepted" do
      assert {:ok, %EDTF.Date{type: :season, values: [1999, 21]}} = EDTF.parse("1999-21")
      assert {:ok, %EDTF.Date{type: :season, values: [1999, 41]}} = EDTF.parse("1999-41")
    end
  end

  describe "parse/1 accepts real dates" do
    test "ordinary valid dates" do
      assert {:ok, %EDTF.Date{values: [1999, 1, 28]}} = EDTF.parse("1999-02-28")
      assert {:ok, %EDTF.Date{values: [2021, 11, 31]}} = EDTF.parse("2021-12-31")
    end

    test "February 29 on leap years" do
      assert {:ok, %EDTF.Date{values: [2000, 1, 29]}} = EDTF.parse("2000-02-29")
      assert {:ok, %EDTF.Date{values: [2024, 1, 29]}} = EDTF.parse("2024-02-29")
    end

    test "BCE and year-zero dates use the proleptic Gregorian calendar" do
      assert {:ok, %EDTF.Date{values: [0, 1, 29]}} = EDTF.parse("0000-02-29")
      assert EDTF.parse("0000-02-30") == {:error, :invalid_date}
      assert {:ok, %EDTF.Date{values: [-44, 2, 15]}} = EDTF.parse("-0044-03-15")
      assert EDTF.parse("-2000-02-30") == {:error, :invalid_date}
    end

    test "year-only and year-month dates" do
      assert {:ok, %EDTF.Date{values: [1999]}} = EDTF.parse("1999")
      assert {:ok, %EDTF.Date{values: [1999, 1]}} = EDTF.parse("1999-02")
    end

    test "large Y-form years carry no day and are unaffected" do
      assert {:ok, %EDTF.Date{type: :year, values: [170_000_000]}} = EDTF.parse("Y170000000")
      assert {:ok, %EDTF.Date{type: :year, values: [-170_000_000]}} = EDTF.parse("Y-170000000")
    end
  end

  describe "parse/1 with unspecified digits — wildcard components are trusted" do
    test "a component containing X is not second-guessed" do
      # February has no day 30-39, but the day's units digit is unknown.
      assert {:ok, %EDTF.Date{}} = EDTF.parse("1999-02-3X")
      assert {:ok, %EDTF.Date{}} = EDTF.parse("1999-02-XX")
      assert {:ok, %EDTF.Date{}} = EDTF.parse("1999-0X-30")
      assert {:ok, %EDTF.Date{}} = EDTF.parse("19XX")
      assert {:ok, %EDTF.Date{}} = EDTF.parse("1999-1X")
    end

    test "a fully concrete out-of-range day is still rejected" do
      assert EDTF.parse("1999-02-39") == {:error, :invalid_date}
    end
  end

  describe "parse/1 with unspecified digits — concrete neighbours are still validated" do
    test "a concrete impossible month is rejected even when the day is unknown" do
      assert EDTF.parse("1999-13-XX") == {:error, :invalid_date}
      assert EDTF.parse("1999-00-XX") == {:error, :invalid_date}
    end

    test "a concrete impossible month is rejected even when the year is unknown" do
      assert EDTF.parse("XXXX-13-01") == {:error, :invalid_date}
    end

    test "a concrete out-of-range day is rejected even when the month is unknown" do
      assert EDTF.parse("1999-XX-32") == {:error, :invalid_date}
      assert EDTF.parse("1999-XX-00") == {:error, :invalid_date}
    end

    test "a concrete day that some month can host is accepted when month is unknown" do
      assert {:ok, %EDTF.Date{}} = EDTF.parse("1999-XX-31")
      assert {:ok, %EDTF.Date{}} = EDTF.parse("1999-XX-30")
    end

    test "an unknown year allows February up to day 29 but not beyond" do
      assert {:ok, %EDTF.Date{}} = EDTF.parse("19XX-02-29")
      assert {:ok, %EDTF.Date{}} = EDTF.parse("199X-02-29")
      assert EDTF.parse("19XX-02-30") == {:error, :invalid_date}
    end

    test "an unknown season-code digit is trusted, a concrete bad code is rejected" do
      assert {:ok, %EDTF.Date{type: :season}} = EDTF.parse("1999-2X")
      assert EDTF.parse("1999-42") == {:error, :invalid_date}
    end
  end

  describe "validate/1 surfaces the same result" do
    test "rejects impossible dates" do
      assert EDTF.validate("1999-02-30") == {:error, :invalid_date}
    end

    test "accepts real dates" do
      assert EDTF.validate("1999-02-28") == {:ok, "1999-02-28"}
    end

    test "still distinguishes malformed input" do
      assert EDTF.validate("bad date!") == {:error, :invalid_format}
    end
  end
end
