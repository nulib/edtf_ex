defmodule EDTF.DateTest do
  use ExUnit.Case

  describe "qualification" do
    setup %{edtf: edtf} do
      {:ok, subject} = EDTF.parse(edtf)
      {:ok, %{subject: subject}}
    end

    @tag edtf: "2024~"
    test "approximate (whole)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024]
      assert subject.level == 1
      assert subject.attributes[:approximate]
      refute subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024?"
    test "uncertain (whole)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024]
      assert subject.level == 1
      refute subject.attributes[:approximate]
      assert subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024%"
    test "approximate and uncertain (whole)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024]
      assert subject.level == 1
      assert subject.attributes[:approximate]
      assert subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024-~10"
    test "approximate (month)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024, 9]
      assert subject.level == 2
      assert subject.attributes[:approximate] == 48
      refute subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024-?10"
    test "uncertain (month)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024, 9]
      assert subject.level == 2
      refute subject.attributes[:approximate]
      assert subject.attributes[:uncertain] == 48
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024-%10"
    test "approximate and uncertain (month)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024, 9]
      assert subject.level == 2
      assert subject.attributes[:approximate] == 48
      assert subject.attributes[:uncertain] == 48
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024-10-~08"
    test "approximate (day)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024, 9, 8]
      assert subject.level == 2
      assert subject.attributes[:approximate] == 192
      refute subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024-10-?08"
    test "uncertain (day)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024, 9, 8]
      assert subject.level == 2
      refute subject.attributes[:approximate]
      assert subject.attributes[:uncertain] == 192
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "2024-10-%08"
    test "approximate and uncertain (day)", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2024, 9, 8]
      assert subject.level == 2
      assert subject.attributes[:approximate] == 192
      assert subject.attributes[:uncertain] == 192
      refute subject.attributes[:unspecified]
    end
  end

  describe "unspecified" do
    setup %{edtf: edtf} do
      {:ok, subject} = EDTF.parse(edtf)
      {:ok, %{subject: subject}}
    end

    @tag edtf: "202X"
    test "simple", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [2020]
      assert subject.level == 1
      refute subject.attributes[:approximate]
      refute subject.attributes[:uncertain]
      assert subject.attributes[:unspecified] == 8
    end

    @tag edtf: "X0X0-0X-1X"
    test "complex", %{subject: subject} do
      assert subject.type == :date
      assert subject.values == [0, 0, 10]
      assert subject.level == 2
      refute subject.attributes[:approximate]
      refute subject.attributes[:uncertain]
      assert subject.attributes[:unspecified] == 165
    end

    @tag edtf: "201?"
    test "decade", %{subject: subject} do
      assert subject.type == :decade
      assert subject.values == [201]
      assert subject.level == 1
      refute subject.attributes[:approximate]
      assert subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "-201~"
    test "negative decade", %{subject: subject} do
      assert subject.type == :decade
      assert subject.values == [-201]
      assert subject.level == 1
      assert subject.attributes[:approximate]
      refute subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "20%"
    test "century", %{subject: subject} do
      assert subject.type == :century
      assert subject.values == [20]
      assert subject.level == 1
      assert subject.attributes[:approximate]
      assert subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end

    @tag edtf: "-20?"
    test "negative century", %{subject: subject} do
      assert subject.type == :century
      assert subject.values == [-20]
      assert subject.level == 1
      refute subject.attributes[:approximate]
      assert subject.attributes[:uncertain]
      refute subject.attributes[:unspecified]
    end
  end

  describe "significant digits" do
    setup %{edtf: edtf} do
      {:ok, subject} = EDTF.parse(edtf)
      {:ok, %{subject: subject}}
    end

    @tag edtf: "Y20200S02"
    test "significant digits", %{subject: subject} do
      assert subject.type == :year
      assert subject.values == [20_200]
      assert subject.level == 2
      assert subject.attributes[:significant] == 2
    end

    @tag edtf: "Y20200E3S02"
    test "significant digits with exponent", %{subject: subject} do
      assert subject.type == :year
      assert subject.values == [20_200_000]
      assert subject.level == 2
      assert subject.attributes[:significant] == 2
    end
  end
end
