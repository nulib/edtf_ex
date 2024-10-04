defmodule EDTF.Continuation do
  @moduledoc """
  EDTF Continuation Struct
  """

  defstruct subtype: nil, position: nil, value: nil

  @type t :: %__MODULE__{
          subtype: :list | :set,
          position: :earlier | :later,
          value: EDTF.Date.t()
        }
end
