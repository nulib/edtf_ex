defmodule EDTF.Validate do
  @moduledoc """
  Calendar validation for assembled EDTF structs.

  `EDTF.Parser` only checks structure (digit counts and separators), so an
  impossible value like `"1999-02-30"` or a bad season code matches the shape
  and parses. `valid?/1` walks an assembled tree and rejects dates that can't
  denote a real calendar date.

  ## Unspecified digits (`X`)

  A component is validated only when it is *fully concrete*. A component that
  contains any unspecified digit is treated as a wildcard and trusted, since the
  author explicitly marked it unknown — e.g. `1999-02-3X` is accepted even though
  no day 30–39 exists in February, because the day's units digit is unknown.

  But a fully concrete component is always checked, even when a *neighbouring*
  component is unspecified: `1999-13-XX` and `XXXX-13-01` are rejected (month 13
  is concrete and impossible), and `19XX-02-30` is rejected (day 30 can't fall in
  February). When the year is unspecified we can't know whether it is a leap
  year, so February is allowed up to day 29 (`19XX-02-29` is accepted).

  Qualifiers (`?`, `~`, `%`) don't change the value, so they are always validated.
  Validation leans on the standard library's proleptic-Gregorian calendar,
  matching how `EDTF.DateRange` resolves dates.
  """

  import Bitwise

  alias EDTF.{Aggregate, Date, Interval}

  # Unspecified-mask bit groups (see EDTF.Parser.Helpers.bitmask/6).
  @year_bits 15
  @month_bits 48
  @day_bits 192

  @doc """
  Return `true` when an assembled EDTF struct represents a real calendar date.

  Recurses into intervals and aggregates so every nested date is checked.
  Shapes without anything to verify (years, decades, centuries, infinity, open
  boundaries) are always considered valid.
  """
  def valid?(%Interval{start: start_date, end: end_date}),
    do: valid?(start_date) and valid?(end_date)

  def valid?(%Aggregate{values: values}), do: Enum.all?(values, &valid?/1)

  def valid?(%Date{type: :season, values: [_year, code]} = date),
    do: unknown?(date, @month_bits) or code in 21..41

  def valid?(%Date{type: :date, values: [_year]}), do: true

  def valid?(%Date{type: :date, values: [_year, _month]} = date), do: month_ok?(date)

  def valid?(%Date{type: :date, values: [_year, _month, _day]} = date),
    do: month_ok?(date) and day_ok?(date)

  def valid?(_), do: true

  defp month_ok?(%Date{values: [_year, month | _]} = date),
    do: unknown?(date, @month_bits) or (month + 1) in 1..12

  defp day_ok?(%Date{values: [year, month, day]} = date) do
    cond do
      unknown?(date, @day_bits) -> true
      unknown?(date, @month_bits) -> day in 1..31
      unknown?(date, @year_bits) -> day in 1..max_day(month + 1)
      true -> Calendar.ISO.valid_date?(year, month + 1, day)
    end
  end

  defp max_day(2), do: 29
  defp max_day(month) when month in [4, 6, 9, 11], do: 30
  defp max_day(_), do: 31

  defp unknown?(%Date{attributes: attributes}, bits) do
    mask = Keyword.get(attributes || [], :unspecified, 0)
    (mask &&& bits) != 0
  end
end
