defmodule EDTF.DateRangeTest do
  use ExUnit.Case

  describe "to_date_range/1 — dates" do
    test "full date" do
      assert EDTF.to_date_range("1999-06-10") == {:ok, {~D[1999-06-10], ~D[1999-06-10]}}
    end

    test "year and month" do
      assert EDTF.to_date_range("1999-06") == {:ok, {~D[1999-06-01], ~D[1999-06-30]}}
    end

    test "year and month honors leap years" do
      assert EDTF.to_date_range("2024-02") == {:ok, {~D[2024-02-01], ~D[2024-02-29]}}
      assert EDTF.to_date_range("2023-02") == {:ok, {~D[2023-02-01], ~D[2023-02-28]}}
    end

    test "year only" do
      assert EDTF.to_date_range("1999") == {:ok, {~D[1999-01-01], ~D[1999-12-31]}}
    end

    test "decade" do
      assert EDTF.to_date_range("201") == {:ok, {~D[2010-01-01], ~D[2019-12-31]}}
    end

    test "century" do
      assert EDTF.to_date_range("19") == {:ok, {~D[1900-01-01], ~D[1999-12-31]}}
      assert EDTF.to_date_range("20") == {:ok, {~D[2000-01-01], ~D[2099-12-31]}}
    end

    test "Y-prefixed year within Calendar.ISO range" do
      assert EDTF.to_date_range("Y2020") == {:ok, {~D[2020-01-01], ~D[2020-12-31]}}
    end
  end

  describe "to_date_range/1 — unspecified digits" do
    test "year units (decade equivalent)" do
      assert EDTF.to_date_range("192X") == {:ok, {~D[1920-01-01], ~D[1929-12-31]}}
    end

    test "year tens and units (century equivalent)" do
      assert EDTF.to_date_range("19XX") == {:ok, {~D[1900-01-01], ~D[1999-12-31]}}
    end

    test "year hundreds, tens, and units (millennium equivalent)" do
      assert EDTF.to_date_range("1XXX") == {:ok, {~D[1000-01-01], ~D[1999-12-31]}}
    end

    test "fully-unknown year is unsupported" do
      assert EDTF.to_date_range("XXXX") == {:error, :unsupported}
    end

    test "non-suffix unspecified digits are unsupported" do
      assert EDTF.to_date_range("X9X2") == {:error, :unsupported}
    end

    test "month-component unspecified widens to the full year" do
      assert EDTF.to_date_range("1999-XX") == {:ok, {~D[1999-01-01], ~D[1999-12-31]}}
    end

    test "day-component unspecified widens to the full month" do
      assert EDTF.to_date_range("1999-12-XX") == {:ok, {~D[1999-12-01], ~D[1999-12-31]}}
    end
  end

  describe "to_date_range/1 — seasons" do
    test "spring (northern hemisphere default)" do
      assert EDTF.to_date_range("2020-21") == {:ok, {~D[2020-03-01], ~D[2020-05-31]}}
    end

    test "summer, autumn" do
      assert EDTF.to_date_range("2020-22") == {:ok, {~D[2020-06-01], ~D[2020-08-31]}}
      assert EDTF.to_date_range("2020-23") == {:ok, {~D[2020-09-01], ~D[2020-11-30]}}
    end

    test "winter (northern hemisphere) spans the year boundary" do
      assert EDTF.to_date_range("2020-24") == {:ok, {~D[2020-12-01], ~D[2021-02-28]}}
    end

    test "winter (northern hemisphere) end honors leap year" do
      assert EDTF.to_date_range("2023-24") == {:ok, {~D[2023-12-01], ~D[2024-02-29]}}
    end

    test "southern hemisphere seasons" do
      assert EDTF.to_date_range("2020-29") == {:ok, {~D[2020-09-01], ~D[2020-11-30]}}
      assert EDTF.to_date_range("2020-30") == {:ok, {~D[2020-12-01], ~D[2021-02-28]}}
      assert EDTF.to_date_range("2020-31") == {:ok, {~D[2020-03-01], ~D[2020-05-31]}}
      assert EDTF.to_date_range("2020-32") == {:ok, {~D[2020-06-01], ~D[2020-08-31]}}
    end

    test "quarters" do
      assert EDTF.to_date_range("2020-33") == {:ok, {~D[2020-01-01], ~D[2020-03-31]}}
      assert EDTF.to_date_range("2020-34") == {:ok, {~D[2020-04-01], ~D[2020-06-30]}}
      assert EDTF.to_date_range("2020-35") == {:ok, {~D[2020-07-01], ~D[2020-09-30]}}
      assert EDTF.to_date_range("2020-36") == {:ok, {~D[2020-10-01], ~D[2020-12-31]}}
    end

    test "quadrimesters and semesters" do
      assert EDTF.to_date_range("2020-37") == {:ok, {~D[2020-01-01], ~D[2020-04-30]}}
      assert EDTF.to_date_range("2020-38") == {:ok, {~D[2020-05-01], ~D[2020-08-31]}}
      assert EDTF.to_date_range("2020-39") == {:ok, {~D[2020-09-01], ~D[2020-12-31]}}
      assert EDTF.to_date_range("2020-40") == {:ok, {~D[2020-01-01], ~D[2020-06-30]}}
      assert EDTF.to_date_range("2020-41") == {:ok, {~D[2020-07-01], ~D[2020-12-31]}}
    end
  end

  describe "to_date_range/1 — qualifiers ignored" do
    test "approximate" do
      assert EDTF.to_date_range("1985~") == {:ok, {~D[1985-01-01], ~D[1985-12-31]}}
    end

    test "uncertain" do
      assert EDTF.to_date_range("1985?") == {:ok, {~D[1985-01-01], ~D[1985-12-31]}}
    end

    test "approximate-and-uncertain" do
      assert EDTF.to_date_range("1985-06%") == {:ok, {~D[1985-06-01], ~D[1985-06-30]}}
    end

    test "level-2 component qualifier" do
      assert EDTF.to_date_range("2024-~10") == {:ok, {~D[2024-10-01], ~D[2024-10-31]}}
    end
  end

  describe "to_date_range/1 — intervals" do
    test "bounded date interval" do
      assert EDTF.to_date_range("1985-04-12/1985-06-26") ==
               {:ok, {~D[1985-04-12], ~D[1985-06-26]}}
    end

    test "year-only intervals widen to year boundaries" do
      assert EDTF.to_date_range("1985/1990") == {:ok, {~D[1985-01-01], ~D[1990-12-31]}}
    end

    test "open end (..)" do
      assert EDTF.to_date_range("1985/..") == {:ok, {~D[1985-01-01], :unbounded}}
    end

    test "open start (..)" do
      assert EDTF.to_date_range("../1985") == {:ok, {:unbounded, ~D[1985-12-31]}}
    end

    test "unknown end" do
      assert EDTF.to_date_range("1985/") == {:ok, {~D[1985-01-01], :unknown}}
    end

    test "unknown start" do
      assert EDTF.to_date_range("/1985") == {:ok, {:unknown, ~D[1985-12-31]}}
    end

    test "reversed interval is normalized to chronological order" do
      assert EDTF.to_date_range("1999/1980") == {:ok, {~D[1980-01-01], ~D[1999-12-31]}}
    end

    test "reversed year-month interval is normalized" do
      assert EDTF.to_date_range("1985-06/1985-04") ==
               {:ok, {~D[1985-04-01], ~D[1985-06-30]}}
    end

    test "reversed full-date interval is normalized" do
      assert EDTF.to_date_range("1985-06-26/1985-04-12") ==
               {:ok, {~D[1985-04-12], ~D[1985-06-26]}}
    end
  end

  describe "to_date_range/1 — aggregates" do
    test "list of bare years" do
      assert EDTF.to_date_range("[1667, 1668, 1670]") ==
               {:ok, {~D[1667-01-01], ~D[1670-12-31]}}
    end

    test "list with a sub-interval" do
      assert EDTF.to_date_range("[1667, 1668, 1670..1672]") ==
               {:ok, {~D[1667-01-01], ~D[1672-12-31]}}
    end

    test "set of year-months" do
      assert EDTF.to_date_range("{2019-06, 2020-06}") ==
               {:ok, {~D[2019-06-01], ~D[2020-06-30]}}
    end

    test "earlier continuation" do
      assert EDTF.to_date_range("[..2020]") == {:ok, {:unbounded, ~D[2020-12-31]}}
    end

    test "later continuation" do
      assert EDTF.to_date_range("[2020..]") == {:ok, {~D[2020-01-01], :unbounded}}
    end

    test "earlier and later continuations" do
      assert EDTF.to_date_range("[..2018, 2020..]") == {:ok, {:unbounded, :unbounded}}
    end
  end

  describe "to_date_range/1 — BCE" do
    test "BCE year" do
      assert EDTF.to_date_range("-0044") == {:ok, {~D[-0044-01-01], ~D[-0044-12-31]}}
    end

    test "BCE year-month" do
      assert EDTF.to_date_range("-1985-06") == {:ok, {~D[-1985-06-01], ~D[-1985-06-30]}}
    end

    test "BCE full date" do
      assert EDTF.to_date_range("-1985-06-10") == {:ok, {~D[-1985-06-10], ~D[-1985-06-10]}}
    end

    test "BCE decade widens toward deeper antiquity (matches humanize \"2010s BCE\")" do
      assert EDTF.to_date_range("-201") == {:ok, {~D[-2019-01-01], ~D[-2010-12-31]}}
    end

    test "BCE century widens toward deeper antiquity (matches humanize \"19th Century BCE\")" do
      assert EDTF.to_date_range("-19") == {:ok, {~D[-1999-01-01], ~D[-1900-12-31]}}
    end

    test "BCE year with unspecified units digit" do
      assert EDTF.to_date_range("-192X") == {:ok, {~D[-1929-01-01], ~D[-1920-12-31]}}
    end

    test "BCE season" do
      assert EDTF.to_date_range("-1985-21") == {:ok, {~D[-1985-03-01], ~D[-1985-05-31]}}
    end

    test "BCE interval" do
      assert EDTF.to_date_range("-0100/-0044") == {:ok, {~D[-0100-01-01], ~D[-0044-12-31]}}
    end
  end

  describe "to_date_range/1 — extreme years (passed through to Date.new/3)" do
    test "Y-prefixed year above 9999" do
      assert EDTF.to_date_range("Y20020") ==
               {:ok, {Date.new!(20_020, 1, 1), Date.new!(20_020, 12, 31)}}
    end

    test "exponential year" do
      assert EDTF.to_date_range("Y17E7") ==
               {:ok, {Date.new!(170_000_000, 1, 1), Date.new!(170_000_000, 12, 31)}}
    end

    test "year below -9999" do
      assert EDTF.to_date_range("Y-20020") ==
               {:ok, {Date.new!(-20_020, 1, 1), Date.new!(-20_020, 12, 31)}}
    end
  end

  describe "to_date_range/1 — errors" do
    test "invalid format" do
      assert EDTF.to_date_range("bad date!") == {:error, :invalid_format}
    end
  end

  describe "to_date_range/1 — input shapes" do
    test "accepts a parsed struct" do
      {:ok, parsed} = EDTF.parse("1985-04-12/1985-06-26")

      assert EDTF.to_date_range(parsed) ==
               {:ok, {~D[1985-04-12], ~D[1985-06-26]}}
    end

    test "accepts the {:ok, struct} parse result directly" do
      assert EDTF.parse("1999") |> EDTF.DateRange.to_date_range() ==
               {:ok, {~D[1999-01-01], ~D[1999-12-31]}}
    end

    test "passes through {:error, _} parse failures" do
      assert EDTF.parse("bad date!") |> EDTF.DateRange.to_date_range() ==
               {:error, :invalid_format}
    end
  end
end
