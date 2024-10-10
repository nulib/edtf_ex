defmodule EDTF.Parser do
  @moduledoc """
  NimbleParsec parser for EDTF dates
  """

  import NimbleParsec
  alias EDTF.Parser.Helpers

  # Basic combinators
  qualifier = ascii_char([??, ?~, ?%])
  component_qualifier = lookahead_not(qualifier |> concat(eos())) |> concat(qualifier)
  digit = ascii_char([?0..?9])
  digit_or_x = ascii_char([?0..?9, ?X])
  sign = ascii_char([?+, ?-])
  year = times(digit_or_x, 4)
  month = times(digit_or_x, 2)
  day = times(digit_or_x, 2)

  # Signed year with optional qualifier
  qualified_year =
    optional(component_qualifier |> tag(:qualifier))
    |> concat(optional(sign) |> tag(:sign))
    |> concat(year |> tag(:value))
    |> post_traverse({Helpers, :bitmask, [0]})

  # Month with optional qualifier
  qualified_month =
    optional(component_qualifier |> tag(:qualifier))
    |> concat(month |> tag(:value))
    |> post_traverse({Helpers, :bitmask, [4]})

  # Day with optional qualifier
  qualified_day =
    optional(component_qualifier |> tag(:qualifier))
    |> concat(day |> tag(:value))
    |> post_traverse({Helpers, :bitmask, [6]})

  # Basic [-]YYYY[-MM[-DD]] with optional qualifiers
  edtf_date =
    qualified_year
    |> optional(ignore(string("-")) |> concat(qualified_month))
    |> optional(ignore(string("-")) |> concat(qualified_day))
    |> optional(tag(qualifier, :qualifier))
    |> post_traverse({Helpers, :reduce, []})

  # Continuation / Range Operator (..)
  continuation = times(ascii_char([?.]), 2) |> replace(true)

  # Range ([date]..[date])
  range =
    tag(edtf_date, :start)
    |> concat(ignore(continuation))
    |> concat(tag(edtf_date, :end))

  # Aggregates (Sets, Lists, and Intervals)
  aggregate_item = choice([tag(range, :interval), edtf_date]) |> wrap()
  aggregate_separator = ignore(string(",")) |> ignore(optional(repeat(ascii_char(~c" "))))

  aggregate_values =
    optional(continuation |> unwrap_and_tag(:earlier))
    |> concat(
      aggregate_item
      |> repeat(aggregate_separator |> concat(aggregate_item))
      |> tag(:dates)
    )
    |> concat(optional(continuation |> unwrap_and_tag(:later)))

  edtf_interval =
    optional(choice([continuation |> replace(:infinity), edtf_date]) |> tag(:start))
    |> ignore(ascii_char([?/]))
    |> optional(choice([continuation |> replace(:infinity), edtf_date]) |> tag(:end))

  edtf_list =
    ignore(ascii_char([?{]))
    |> concat(aggregate_values)
    |> concat(ignore(ascii_char([?}])))

  edtf_set =
    ignore(ascii_char([?[]))
    |> concat(aggregate_values)
    |> concat(ignore(ascii_char([?]])))

  # Level 0 Century and Decade
  signed_integer = fn digits ->
    optional(sign |> tag(:sign))
    |> concat(
      times(digit, digits)
      |> post_traverse({Helpers, :to_integer, []})
      |> unwrap_and_tag(:value)
      |> wrap()
    )
    |> concat(optional(qualifier) |> tag(:qualifier))
    |> post_traverse({Helpers, :apply_sign, []})
    |> post_traverse({Helpers, :apply_qualifier, []})
  end

  edtf_century = signed_integer.(2)
  edtf_decade = signed_integer.(3)

  # Level 2 Years with optional exponents and significant digits
  exponent = ignore(ascii_char([?E])) |> concat(integer(min: 1) |> unwrap_and_tag(:exponent))

  significant =
    ignore(ascii_char([?S])) |> concat(integer(min: 1) |> unwrap_and_tag(:significant))

  qualified_year =
    optional(sign |> tag(:sign))
    |> concat(integer(min: 1) |> unwrap_and_tag(:value))
    |> post_traverse({Helpers, :apply_sign, []})

  edtf_year =
    choice([
      optional(ignore(ascii_char([?Y]))) |> concat(qualified_year),
      lookahead(choice([exponent, significant])) |> concat(qualified_year)
    ])
    |> tag(
      optional(exponent) |> concat(optional(significant)),
      :attributes
    )

  defparsec(
    :parse,
    choice([
      tag(edtf_date, :date) |> eos(),
      tag(edtf_century, :century) |> eos(),
      tag(edtf_decade, :decade) |> eos(),
      tag(edtf_year, :year) |> eos(),
      tag(edtf_interval, :interval) |> eos(),
      tag(edtf_list, :list) |> eos(),
      tag(edtf_set, :set) |> eos()
    ])
  )
end
