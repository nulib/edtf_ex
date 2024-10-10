defmodule EDTF.LevelTest do
  use ExUnit.Case
  alias EDTF.Level

  describe "add_level/1" do
    test "errors pass through" do
      assert {:error, :no_level} |> Level.add_level() == {:error, :no_level}
    end

    test "status-wrapped value" do
      date = EDTF.parse("2024")
      assert Level.add_level(date) == date
    end
  end
end
