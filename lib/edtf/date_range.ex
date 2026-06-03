defmodule EDTF.DateRange do
  @moduledoc """
  Convert parsed EDTF structs into a `{start_date, end_date}` tuple of
  `Date.t()` values suitable for SQL- or Ecto-style range queries.

  The user-facing entry point is `EDTF.to_date_range/1`, which accepts an EDTF
  string and delegates here once parsing has succeeded. This module can also be
  called directly with an already-parsed struct.

  ## Semantics

  - Bounded inputs yield two concrete `Date.t()` values.
  - Explicitly open inputs (`/..`, `../`, `[..2020]`, `[2020..]`) yield
    `:unbounded` on the open side.
  - Inputs with an unknown bound (`1985/`, `/1985`) yield `:unknown` on that
    side.
  - Qualifiers (`~`, `?`, `%`) are ignored — the range uses the nominal date.
  - Unspecified digits (`X`) forming a contiguous suffix of a component expand to
    that suffix's span: `19XX` → 1900–1999, `2020-1X` → Oct–Dec 2020,
    `2020-12-3X` → Dec 30–31 2020. A fully-unknown month or day widens to the
    whole year or month respectively. Non-suffix unknown digits (`X9X2`,
    `2020-X2`), a fully-unknown year (`XXXX`), and suffixes that can't denote a
    real date (`2020-02-3X`) return `{:error, :unsupported}`.
  - Seasons map to month ranges (quarters, quadrimesters, semesters are
    unambiguous; codes 21–24 are treated as northern-hemisphere; Winter and
    southern-hemisphere Summer span the year boundary).
  """

  import Bitwise

  alias EDTF.{Aggregate, Infinity, Interval}

  @season_months %{
    21 => {3, 5},
    22 => {6, 8},
    23 => {9, 11},
    24 => :winter_north,
    25 => {3, 5},
    26 => {6, 8},
    27 => {9, 11},
    28 => :winter_north,
    29 => {9, 11},
    30 => :summer_south,
    31 => {3, 5},
    32 => {6, 8},
    33 => {1, 3},
    34 => {4, 6},
    35 => {7, 9},
    36 => {10, 12},
    37 => {1, 4},
    38 => {5, 8},
    39 => {9, 12},
    40 => {1, 6},
    41 => {7, 12}
  }

  @year_span_for_mask %{0 => 0, 8 => 9, 12 => 99, 14 => 999}

  # Unspecified-mask bit groups (see EDTF.Parser.Helpers.bitmask/6). The `_units`
  # masks are the trailing digit of a component — the only sub-year suffix that
  # expands to a clean span; a leading-digit (non-suffix) mask falls through.
  @year_bits 15
  @month_bits 48
  @month_units 32
  @day_bits 192
  @day_units 128

  @doc """
  Convert a parsed EDTF struct (or a `parse/1` result tuple) into a
  `{start_date, end_date}` tuple.
  """
  def to_date_range({:ok, value}), do: to_date_range(value)
  def to_date_range({:error, _} = error), do: error

  def to_date_range(%EDTF.Date{} = date) do
    mask = unspecified_mask(date)

    if mask == 0 do
      from_date(date)
    else
      from_unspecified(date, mask)
    end
  end

  def to_date_range(%Interval{start: start_boundary, end: end_boundary}) do
    with {:ok, start_range} <- resolve_boundary(start_boundary),
         {:ok, end_range} <- resolve_boundary(end_boundary) do
      {:ok, interval_envelope(start_range, end_range)}
    end
  end

  def to_date_range(%Aggregate{values: []}), do: {:error, :unsupported}

  def to_date_range(%Aggregate{values: values, earlier: earlier, later: later}) do
    ranges =
      values
      |> Enum.map(&to_date_range/1)
      |> Enum.flat_map(fn
        {:ok, range} -> [range]
        _ -> []
      end)

    case ranges do
      [] ->
        {:error, :unsupported}

      _ ->
        start_date = if earlier, do: :unbounded, else: earliest_start(ranges)
        end_date = if later, do: :unbounded, else: latest_end(ranges)
        {:ok, {start_date, end_date}}
    end
  end

  def to_date_range(_), do: {:error, :unsupported}

  defp from_date(%EDTF.Date{type: :date, values: [year, month, day]}) do
    case Date.new(year, month + 1, day) do
      {:ok, date} -> {:ok, {date, date}}
      _ -> {:error, :out_of_range}
    end
  end

  defp from_date(%EDTF.Date{type: :date, values: [year, month]}) do
    month_range(year, month + 1)
  end

  defp from_date(%EDTF.Date{type: :date, values: [year]}), do: year_range(year)
  defp from_date(%EDTF.Date{type: :year, values: [year]}), do: year_range(year)

  defp from_date(%EDTF.Date{type: :decade, values: [decade]}) do
    span_range(decade * 10, 9)
  end

  defp from_date(%EDTF.Date{type: :century, values: [century]}) do
    span_range(century * 100, 99)
  end

  defp from_date(%EDTF.Date{type: :season, values: [year, code]}) do
    season_range(year, Map.get(@season_months, code))
  end

  defp from_date(_), do: {:error, :unsupported}

  defp from_unspecified(%EDTF.Date{values: values, type: :date}, mask) do
    year_bits = mask &&& @year_bits
    month_bits = mask &&& @month_bits
    day_bits = mask &&& @day_bits

    cond do
      year_bits != 0 -> unspecified_year_range(values, year_bits)
      month_bits != 0 -> unspecified_month_range(values, month_bits)
      day_bits != 0 and match?([_, _ | _], values) -> unspecified_day_range(values, day_bits)
      true -> {:error, :unsupported}
    end
  end

  defp from_unspecified(_, _), do: {:error, :unsupported}

  # Only a contiguous suffix expands cleanly: a fully-unknown or non-suffix year
  # isn't in the table, so it declines.
  defp unspecified_year_range([year | _], year_bits) do
    case Map.get(@year_span_for_mask, year_bits) do
      nil -> {:error, :unsupported}
      span -> span_range(year, span)
    end
  end

  defp unspecified_month_range([year | _], @month_bits), do: month_span(year, 1, 12)

  defp unspecified_month_range([year, month | _], @month_units) do
    tens = div(month + 1, 10)
    month_span(year, tens * 10, tens * 10 + 9)
  end

  defp unspecified_month_range(_, _), do: {:error, :unsupported}

  defp unspecified_day_range([year, month | _], @day_bits), do: month_range(year, month + 1)

  defp unspecified_day_range([year, month, day], @day_units) do
    tens = div(day, 10)
    day_span(year, month + 1, tens * 10, tens * 10 + 9)
  end

  defp unspecified_day_range(_, _), do: {:error, :unsupported}

  defp month_span(year, low, high) do
    start_month = max(low, 1)
    end_month = min(high, 12)

    if start_month > end_month do
      {:error, :unsupported}
    else
      with {:ok, start_date} <- Date.new(year, start_month, 1),
           {:ok, end_pivot} <- Date.new(year, end_month, 1) do
        end_date = Date.new!(year, end_month, Date.days_in_month(end_pivot))
        {:ok, {start_date, end_date}}
      else
        _ -> {:error, :out_of_range}
      end
    end
  end

  # An empty span (e.g. `02-3X`: no day 30-39 exists in February) has no range.
  defp day_span(year, month, low, high) do
    case Date.new(year, month, 1) do
      {:ok, first} ->
        start_day = max(low, 1)
        end_day = min(high, Date.days_in_month(first))

        if start_day > end_day do
          {:error, :unsupported}
        else
          {:ok, {Date.new!(year, month, start_day), Date.new!(year, month, end_day)}}
        end

      _ ->
        {:error, :out_of_range}
    end
  end

  defp year_range(year), do: span_range(year, 0)

  defp month_range(year, month) when month in 1..12 do
    case Date.new(year, month, 1) do
      {:ok, start_date} ->
        end_date = Date.new!(year, month, Date.days_in_month(start_date))
        {:ok, {start_date, end_date}}

      _ ->
        {:error, :out_of_range}
    end
  end

  defp month_range(_, _), do: {:error, :out_of_range}

  defp span_range(year, span) do
    {start_year, end_year} = span_bounds(year, span)

    with {:ok, start_date} <- Date.new(start_year, 1, 1),
         {:ok, end_date} <- Date.new(end_year, 12, 31) do
      {:ok, {start_date, end_date}}
    else
      _ -> {:error, :out_of_range}
    end
  end

  # For BCE values, widen *away from zero* so the range matches the colloquial
  # decade/century the humanize module prints (decade -201 → "2010s BCE" →
  # years -2019..-2010, not -2010..-2001).
  defp span_bounds(year, 0), do: {year, year}
  defp span_bounds(year, span) when year >= 0, do: {year, year + span}
  defp span_bounds(year, span), do: {year - span, year}

  defp season_range(_year, nil), do: {:error, :unsupported}

  defp season_range(year, :winter_north), do: cross_year_range(year, 12, year + 1, 2)
  defp season_range(year, :summer_south), do: cross_year_range(year, 12, year + 1, 2)

  defp season_range(year, {start_month, end_month}) do
    with {:ok, start_date} <- Date.new(year, start_month, 1),
         {:ok, end_pivot} <- Date.new(year, end_month, 1) do
      end_date = Date.new!(year, end_month, Date.days_in_month(end_pivot))
      {:ok, {start_date, end_date}}
    else
      _ -> {:error, :out_of_range}
    end
  end

  defp cross_year_range(start_year, start_month, end_year, end_month) do
    with {:ok, start_date} <- Date.new(start_year, start_month, 1),
         {:ok, end_pivot} <- Date.new(end_year, end_month, 1) do
      end_date = Date.new!(end_year, end_month, Date.days_in_month(end_pivot))
      {:ok, {start_date, end_date}}
    else
      _ -> {:error, :out_of_range}
    end
  end

  defp resolve_boundary(:unknown), do: {:ok, :unknown}
  defp resolve_boundary(nil), do: {:ok, :unknown}
  defp resolve_boundary(%Infinity{}), do: {:ok, :unbounded}
  defp resolve_boundary(%EDTF.Date{} = date), do: to_date_range(date)

  defp interval_envelope(a, b) when a in [:unbounded, :unknown] and b in [:unbounded, :unknown],
    do: {a, b}

  defp interval_envelope(a, {_, b_end}) when a in [:unbounded, :unknown], do: {a, b_end}
  defp interval_envelope({a_start, _}, b) when b in [:unbounded, :unknown], do: {a_start, b}

  defp interval_envelope({a_start, a_end}, {b_start, b_end}) do
    {Enum.min([a_start, b_start], Date), Enum.max([a_end, b_end], Date)}
  end

  defp unspecified_mask(%EDTF.Date{attributes: attrs}) when is_list(attrs) do
    Keyword.get(attrs, :unspecified) || 0
  end

  defp unspecified_mask(_), do: 0

  defp earliest_start(ranges) do
    ranges
    |> Enum.map(fn {start_date, _} -> start_date end)
    |> Enum.reject(&is_atom/1)
    |> min_date()
  end

  defp latest_end(ranges) do
    ranges
    |> Enum.map(fn {_, end_date} -> end_date end)
    |> Enum.reject(&is_atom/1)
    |> max_date()
  end

  defp min_date([]), do: :unknown
  defp min_date(dates), do: Enum.min(dates, Date)

  defp max_date([]), do: :unknown
  defp max_date(dates), do: Enum.max(dates, Date)
end
