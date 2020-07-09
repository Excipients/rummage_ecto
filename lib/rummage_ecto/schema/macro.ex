defmodule Rummage.Ecto.Schema.Macro do
  @moduledoc """
  Usage:
  ```elixir
  defmodule MyApp.Rummage.MyModel do
    use Rummage.Schema,
      paginate: MyApp.Rummage.Paginate,
      sort: MyApp.Rummage.MyModel.Sort,
      search: MyApp.Rummage.MyModel.Search,
      schema: MyApp.MyModel
  end
  ```
  """

  defmacro __using__(opts) do
    paginate = Keyword.fetch!(opts, :paginate)
    sort = Keyword.fetch!(opts, :sort)
    search = Keyword.fetch!(opts, :search)
    schema = Keyword.fetch!(opts, :schema)
    repo = Keyword.get(opts, :repo, Rummage.Ecto.Config.repo())

    quote location: :keep do
      use Ecto.Schema
      import Ecto.Changeset
      import Ecto.Query, warn: false

      @primary_key false
      embedded_schema do
        embeds_one(:paginate, unquote(paginate))
        embeds_one(:search, unquote(search))
        embeds_one(:sort, unquote(sort))

        field(:params, :map)
        field(:changeset, :map)
      end

      def changeset(nil), do: changeset(struct(__MODULE__), %{})
      def changeset(attrs), do: changeset(struct(__MODULE__), attrs)

      def changeset(rummage_schema, attrs) do
        attrs = Map.put_new(attrs, "paginate", %{})
        attrs = Map.put_new(attrs, "search", %{})
        attrs = Map.put_new(attrs, "sort", %{})

        rummage_schema
        |> cast(attrs, [])
        |> cast_embed(:paginate)
        |> cast_embed(:search)
        |> cast_embed(:sort)
      end

      def rummage(params, opts \\ []) do
        query = Keyword.get(opts, :query, unquote(schema))

        changeset = changeset(params)
        rummage = apply_changes(changeset)

        # changest - For use w/ 'search' form
        rummage = Map.put(rummage, :changeset, changeset)

        {query, rummage} =
          query
          |> search(rummage)
          |> sort(rummage)
          |> paginate(rummage)

        query =
          case Keyword.get(opts, :preload) do
            nil -> query
            preload -> from(a in query, preload: ^preload)
          end

        records = unquote(repo).all(query)

        paginate_params =
          if rummage.paginate do
            %{page: rummage.paginate.page, per_page: rummage.paginate.per_page}
          else
            nil
          end

        search_params =
          if rummage.search do
            Map.from_struct(rummage.search)
          else
            nil
          end

        sort_params =
          if rummage.sort do
            Map.from_struct(rummage.sort)
          else
            nil
          end

        # params - For use w/ sort and paginate links...
        rummage =
          Map.put(rummage, :params, %{
            paginate: paginate_params,
            search: search_params,
            sort: sort_params
          })

        {rummage, records}
      end

      # Note: rummage.paginate is modified - it gets a total_count
      defp paginate(query, %{paginate: paginate} = rummage) do
        {query, paginate} = unquote(paginate).rummage(query, paginate)
        {query, Map.put(rummage, :paginate, paginate)}
      end

      defp search(query, %{search: search}) do
        unquote(search).rummage(query, search)
      end

      defp sort(query, %{sort: sort}) do
        unquote(sort).rummage(query, sort)
      end
    end
  end
end
