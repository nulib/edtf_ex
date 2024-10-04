defmodule EDTF.Infinity do
  defstruct []
  @type t :: %__MODULE__{}

  def match?(".."), do: true
  def match?(_), do: false
  def parse(".."), do: {:ok, %__MODULE__{}}
  def parse(_), do: EDTF.invalid()
end
