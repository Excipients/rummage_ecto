defmodule Rummage.Ecto.Schema.SearchTest do
  use ExUnit.Case
  doctest Rummage.Ecto.Schema.Search

  alias Rummage.Ecto.Repo
  alias Rummage.Ecto.Product
  alias Rummage.Ecto.Category

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
  end

  defp create_categories_and_products() do
    for x <- 1..4 do
      parent_category =
        %Category{name: "Parent Category #{10 - x}"}
        |> Repo.insert!()

      category =
        %Category{name: "Category #{x}", parent_category: parent_category}
        |> Repo.insert!()

      for y <- 1..2 do
        %Product{
          internal_code: "#{x}-#{y}",
          name: "Product #{x}-#{y}",
          price: 10.0 * x,
          category: category
        }
        |> Repo.insert!()
      end
    end
  end

  test "changeset (default)" do
    params = %{}

    changeset =
      Rummage.Ecto.Rummage.Product.Search.changeset(
        %Rummage.Ecto.Rummage.Product.Search{},
        params
      )

    assert changeset.changes == %{}
    assert changeset.data == %Rummage.Ecto.Rummage.Product.Search{}
    assert changeset.params == %{}
  end

  test "changeset" do
    params = %{"name" => "3-", "price_gteq" => "10.1"}

    changeset =
      Rummage.Ecto.Rummage.Product.Search.changeset(
        %Rummage.Ecto.Rummage.Product.Search{},
        params
      )

    assert changeset.changes == %{name: "3-", price_gteq: 10.1}
    assert changeset.data == %Rummage.Ecto.Rummage.Product.Search{}
    assert changeset.params == %{"name" => "3-", "price_gteq" => "10.1"}
  end

  test "rummage" do
    create_categories_and_products()

    params = %Rummage.Ecto.Rummage.Product.Search{name: "3-"}

    products =
      Rummage.Ecto.Product
      |> Rummage.Ecto.Rummage.Product.Search.rummage(params)
      |> Repo.all()

    assert length(products) == 2
    assert Enum.map(products, & &1.name) == ["Product 3-1", "Product 3-2"]
  end
end
