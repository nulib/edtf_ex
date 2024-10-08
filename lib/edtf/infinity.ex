defmodule EDTF.Infinity do
  @moduledoc """
  EDTF Infinity struct
  """

  defstruct level: 1
  @type t :: %__MODULE__{level: integer()}

  def match?(".."), do: true
  def match?(_), do: false
  def parse(".."), do: {:ok, %__MODULE__{level: 1}}
  def parse(_), do: EDTF.error()
end
