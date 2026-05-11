defmodule EDTF.DateRange do
  @moduledoc """
  Convert parsed EDTF structs into a `{start_date, end_date}` tuple of
  `Date.t()` values suitable for SQL- or Ecto-style range queries.

  The user-facing entry point is `EDTF.to_date_range/1`, which accepts an EDTF
  string and delegates here once parsing has succeeded. This module can also be
  called directly with an already-parsed struct.

  ## Semantics

  - Bounded inputs yield two concrete `Date.t()` values.
  - Unbounded inputs (`/..`, `../`, `[..2020]`, `[2020..]`, unknown bounds)
    yield `nil` on the unbounded side.
  - Qualifiers (`~`, `?`, `%`) are ignored — the range uses the nominal date.
  - Unspecified digits (`X`) are expanded to their full place-value span when
    they form a contiguous suffix of a component (e.g. `19XX` → 1900-01-01 to
    1999-12-31). Non-suffix unspecified digits return `{:error, :unsupported}`.
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
        start_date = if earlier, do: nil, else: earliest_start(ranges)
        end_date = if later, do: nil, else: latest_end(ranges)
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
    year_bits = mask &&& 15
    month_bits = mask &&& 48
    day_bits = mask &&& 192

    cond do
      year_bits == 15 ->
        {:error, :unsupported}

      year_bits != 0 and not Map.has_key?(@year_span_for_mask, year_bits) ->
        {:error, :unsupported}

      year_bits != 0 ->
        span_range(hd(values), Map.fetch!(@year_span_for_mask, year_bits))

      month_bits != 0 ->
        year_range(hd(values))

      day_bits != 0 and match?([_, _ | _], values) ->
        [year, month | _] = values
        month_range(year, month + 1)

      true ->
        {:error, :unsupported}
    end
  end

  defp from_unspecified(_, _), do: {:error, :unsupported}

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

  defp resolve_boundary(:unknown), do: {:ok, nil}
  defp resolve_boundary(nil), do: {:ok, nil}
  defp resolve_boundary(%Infinity{}), do: {:ok, nil}
  defp resolve_boundary(%EDTF.Date{} = date), do: to_date_range(date)

  defp interval_envelope(nil, nil), do: {nil, nil}
  defp interval_envelope(nil, {_, b_end}), do: {nil, b_end}
  defp interval_envelope({a_start, _}, nil), do: {a_start, nil}

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
    |> Enum.reject(&is_nil/1)
    |> min_date()
  end

  defp latest_end(ranges) do
    ranges
    |> Enum.map(fn {_, end_date} -> end_date end)
    |> Enum.reject(&is_nil/1)
    |> max_date()
  end

  defp min_date([]), do: nil
  defp min_date(dates), do: Enum.min(dates, Date)

  defp max_date([]), do: nil
  defp max_date(dates), do: Enum.max(dates, Date)
end
