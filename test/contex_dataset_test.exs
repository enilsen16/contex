defmodule ContexDatasetTest do
  use ExUnit.Case

  alias Contex.Dataset

  doctest Contex.Dataset

  setup do
    dataset_maps = Dataset.new([%{y: 1, x: 2, z: 5}, %{x: 3, y: 4, z: 6}])
    dataset_nocols = Dataset.new([{1, 2, 3, 4}, {4, 5, 6, 4}, {-3, -2, -1, 0}])
    dataset = Dataset.new(dataset_nocols.data, ["aa", "bb", "cccc", "d"])
    %{dataset_maps: dataset_maps, dataset_nocols: dataset_nocols, dataset: dataset}
  end

  describe "new/1" do
    test "returns a Dataset struct with no headers when passed a list" do
      dataset = Dataset.new([{1, 2}, {1, 2}])
      assert %Dataset{} = dataset
      assert dataset.headers == nil
    end

    test "raises when not passed a list" do
      data = {{1, 2}, {1, 2}}
      assert_raise FunctionClauseError, fn -> Dataset.new(data) end
    end
  end

  describe "new/2" do
    test "returns a Dataset struct with headers when passed two lists" do
      dataset = Dataset.new([{1, 2}, {1, 2}], ["x", "y"])
      assert %Dataset{} = dataset
      assert dataset.headers == ["x", "y"]
    end

    test "raises when not passed two lists" do
      data = {{1, 2}, {1, 2}}
      headers = {"x", "y"}
      assert_raise FunctionClauseError, fn -> Dataset.new(data, headers) end

      data = [{1, 2}, {1, 2}]
      headers = {"x", "y"}
      assert_raise FunctionClauseError, fn -> Dataset.new(data, headers) end

      data = {{1, 2}, {1, 2}}
      headers = ["x", "y"]
      assert_raise FunctionClauseError, fn -> Dataset.new(data, headers) end
    end

    test "returns a dataset struct with data in a map when passed a list of maps" do
      list_of_maps = [%{y: 1, x: 2, z: 5}, %{x: 3, y: 4, z: 6}]
      dataset = Dataset.new(list_of_maps)
      assert %Dataset{} = dataset
      assert dataset.data == list_of_maps
      assert dataset.headers == nil
    end
  end

  describe "column_names/1" do
    test "returns names if data is a map", %{dataset_maps: dataset_maps} do
      assert [:x, :y, :z] ==
               Dataset.column_names(dataset_maps)
               |> Enum.sort()
    end

    test "returns names if data has headers", %{dataset: dataset} do
      assert ["aa", "bb", "cccc", "d"] == Dataset.column_names(dataset)
    end

    test "returns names if tuple data does not have headers", %{dataset_nocols: dataset_nocols} do
      assert [0, 1, 2, 3] == Dataset.column_names(dataset_nocols)
    end

    test "returns names if list data does not have headers" do
      assert [0, 1, 2, 3] ==
               Dataset.new([[1, 2, 3, 4], [4, 5, 6, 4], [-3, -2, -1, 0]])
               |> Dataset.column_names()
    end
  end

  describe "column_index/2" do
    test "returns map key if data is a map", %{dataset_maps: dataset_maps} do
      assert Dataset.column_index(dataset_maps, :x) == :x
    end

    test "returns nil if column name is not a map key", %{dataset_maps: dataset_maps} do
      assert Dataset.column_index(dataset_maps, :not_a_key) == nil
      # assert_raise(
      #   ArgumentError,
      #   "Column name provided is not a key in the data map.",
      #   fn -> Dataset.column_index(dataset_maps, :not_a_key) end
      # )
    end

    test "returns nil if dataset has no headers", %{dataset_nocols: dataset_nocols} do
      assert Dataset.column_index(dataset_nocols, "bb") == nil
    end

    test "returns index of header value in headers list if it exists", %{dataset: dataset} do
      assert Dataset.column_index(dataset, "bb") == 1
    end

    test "returns nil if header not in list", %{dataset: dataset} do
      assert Dataset.column_index(dataset, "bbb") == nil
    end
  end

  describe "value_fn/2" do
    test "returns accessor function for map data", %{dataset_maps: dataset_maps} do
      accessor = Dataset.value_fn(dataset_maps, :x)
      assert accessor.(hd(dataset_maps.data)) == 2
    end

    test "returns accessor function for tuple data with headers", %{dataset: dataset} do
      accessor = Dataset.value_fn(dataset, "aa")
      assert accessor.(hd(dataset.data)) == 1
    end

    test "returns accessor function for tuple data with no headers", %{
      dataset_nocols: dataset_nocols
    } do
      accessor = Dataset.value_fn(dataset_nocols, 0)
      assert accessor.(hd(dataset_nocols.data)) == 1
    end

    test "returns accessor function for list data with no headers" do
      dataset = Dataset.new([[1, 2, 3, 4], [4, 5, 6, 4], [-3, -2, -1, 0]])
      accessor = Dataset.value_fn(dataset, 0)
      assert accessor.(hd(dataset.data)) == 1
    end
  end

  describe "column_extents/2" do
    test "returns appropriate boundary values for given column header", %{dataset: dataset} do
      assert Dataset.column_extents(dataset, "bb") == {-2, 5}
    end
  end

  describe "column_name/2" do
    test "returns the map key when given the key for a column in map data", %{
      dataset_maps: dataset_maps
    } do
      assert Dataset.column_name(dataset_maps, :x) == :x
    end

    test "looks up the column name for a given index", %{dataset: dataset} do
      assert Dataset.column_name(dataset, 0) == "aa"
    end

    test "returns the index if it is out of bounds", %{dataset: dataset} do
      assert Dataset.column_name(dataset, 10) == 10
    end

    test "returns the index if the dataset has no headers", %{dataset_nocols: dataset_nocols} do
      assert Dataset.column_name(dataset_nocols, 0) == 0
    end
  end

  describe "guess_column_type/2" do
    setup do
      date_time_1 = DateTime.from_unix!(1)
      date_1 = DateTime.to_date(date_time_1)
      naive_date_time_1 = DateTime.to_naive(date_time_1)
      date_time_2 = DateTime.from_unix!(2)
      date_2 = DateTime.to_date(date_time_2)
      naive_date_time_2 = DateTime.to_naive(date_time_2)

      %{
        dataset:
          Dataset.new(
            [
              {1, "foo", date_time_1, naive_date_time_1, date_1},
              {2, "bar", date_time_2, naive_date_time_2, date_2}
            ],
            ["number", "string", "date_time", "naive_date_time", "date"]
          )
      }
    end

    test "guesses numbers", %{dataset: dataset} do
      assert Dataset.guess_column_type(dataset, "number") == :number
    end

    test "guesses strings", %{dataset: dataset} do
      assert Dataset.guess_column_type(dataset, "string") == :string
    end

    test "guesses %DateTime{}s", %{dataset: dataset} do
      assert Dataset.guess_column_type(dataset, "date_time") == :datetime
    end

    test "guesses %NaiveDateTime{}s", %{dataset: dataset} do
      assert Dataset.guess_column_type(dataset, "naive_date_time") == :datetime
    end

    test "guesses %Date{}s", %{dataset: dataset} do
      assert Dataset.guess_column_type(dataset, "date") == :date
    end
  end

  describe "combined_column_extents/2" do
    test "calculates boundary values of row sums of given columns", %{dataset: dataset} do
      assert Dataset.combined_column_extents(dataset, ["aa", "cccc"]) == {-4, 10}
    end
  end

  describe "unique_values/2" do
    test "returns a list of unique values for a given column", %{dataset: dataset} do
      assert Dataset.unique_values(dataset, "d") == [4, 0]
    end
  end
end
