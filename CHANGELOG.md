# Changelog

All notable changes to this project will be documented in this file.

## [v2.0.0](https://github.com/nulib/edtf_ex/releases/tag/v2.0.0) - 2026-06-03

### Breaking Changes
- `EDTF.parse/1` now validates that parsed dates correspond to real calendar dates in addition to checking structural format. Previously, values like `"1999-02-30"` returned `{:ok, …}`; they now return `{:error, :invalid_date}`. To opt out of calendar validation, pass `validate: false` as a second argument: `EDTF.parse("1999-02-30", validate: false)`. The same option is accepted by `EDTF.humanize/2`. ([#41](https://github.com/nulib/edtf_ex/pull/41) by [@weljoda](https://github.com/weljoda))

### Fixed
- `EDTF.to_date_range/1` now expands unspecified trailing digits to their correct tight span rather than the full year or month. For example, `2020-1X` now yields Oct–Dec 2020 and `2020-12-3X` yields Dec 30–31. Non-suffix patterns such as `2020-X2` return `:unsupported`. ([#41](https://github.com/nulib/edtf_ex/pull/41) by [@weljoda](https://github.com/weljoda))

## [v1.4.0](https://github.com/nulib/edtf_ex/releases/tag/v1.4.0) - 2026-05-11

### Added
- `EDTF.to_date_range/1` — expands an EDTF value into a `{Date.t(), Date.t()}` tuple suitable for filtering and sorting ([#39](https://github.com/nulib/edtf_ex/pull/39) by [@weljoda](https://github.com/weljoda))
- Unspecified-digit ranges now expand to their real spans (e.g. `2020-1X` → Oct–Dec 2020) ([#39](https://github.com/nulib/edtf_ex/pull/39) by [@weljoda](https://github.com/weljoda))
- Unbounded and unknown interval endpoints now use `:unbounded` and `:unknown` atoms instead of `nil` ([#39](https://github.com/nulib/edtf_ex/pull/39) by [@weljoda](https://github.com/weljoda))

### Fixed
- Reject single-digit date components that are not compliant with ISO 8601-2 (e.g. `1-2-3`) ([#38](https://github.com/nulib/edtf_ex/pull/38))
- Resolve compile warnings introduced by Elixir 1.19.5 / OTP 28 ([#38](https://github.com/nulib/edtf_ex/pull/38))

## [v1.3.0](https://github.com/nulib/edtf_ex/releases/tag/v1.3.0) - 2025-01-27

### Added
- Level 2 Group Qualifiers — uncertainty and approximation can now be applied to a group of date components with a single qualifier character ([#14](https://github.com/nulib/edtf_ex/pull/14))

## [v1.2.1](https://github.com/nulib/edtf_ex/releases/tag/v1.2.1)

### Fixed
- Corrected the link to the GitHub repository in the package metadata

## [v1.2.0](https://github.com/nulib/edtf_ex/releases/tag/v1.2.0) - 2024-10-11

### Changed
- Replaced Regex-based parsing with a [NimbleParsec](https://github.com/dashbitco/nimble_parsec) grammar for more robust and maintainable parsing ([#1](https://github.com/nulib/edtf_ex/pull/1))

## [v1.1.0](https://github.com/nulib/edtf_ex/releases/tag/v1.1.0)

### Added
- Level 2 qualifications (uncertain, approximate, both) on individual date components
- Years with significant digits (e.g. `1950S2`)

## [v1.0.0](https://github.com/nulib/edtf_ex/releases/tag/v1.0.0)

Initial release with support for EDTF Level 0, 1, and 2 parsing, including dates, seasons, decades, centuries, sets, intervals, and uncertainty/approximation qualifiers.