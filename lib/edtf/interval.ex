defmodule EDTF.Interval do
  @moduledoc """
  Parser for EDTF Intervals
  """

  defstruct start: :unknown,
            end: :unknown,
            level: 2

  @type t :: %__MODULE__{
          start: EDTF.Date.t() | :unknown,
          end: EDTF.Date.t() | :unknown,
          level: integer()
        }

  def assemble([{:interval, value}]), do: assemble({:interval, value})

  def assemble({:interval, value}) do
    start_date = {:date, Keyword.get(value, :start)} |> EDTF.Date.assemble()
    end_date = {:date, Keyword.get(value, :end)} |> EDTF.Date.assemble()
    %__MODULE__{start: start_date, end: end_date}
  end
end
