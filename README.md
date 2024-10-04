# EDTF

[![Build](https://github.com/nulib/edtf_ex/actions/workflows/build.yml/badge.svg)](https://github.com/nulib/edtf_ex/actions/workflows/build.yml)
[![Coverage](https://coveralls.io/repos/github/nulib/edtf_ex/badge.svg?branch=main)](https://coveralls.io/github/nulib/edtf_ex?branch=main)
[![Hex.pm](https://img.shields.io/hexpm/v/edtf_ex.svg)](https://hex.pm/packages/authoritex)

An Extended Date Time Format (EDTF) / ISO 8601-2 parser and English language rendering
toolkit for Elixir.

## Compatibility

### EDTF / ISO 8601-2
EDTF.js fully implements [EDTF](http://www.loc.gov/standards/datetime)
levels 0, 1, and 2 as specified by ISO 8601-2

## Installation

Add `edtf` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:edtf, "~> 1.0.0"}
  ]
end
```

## Usage

See `EDTF.parse/1`, `EDTF.validate/1`, and `EDTF.humanize/1`.
