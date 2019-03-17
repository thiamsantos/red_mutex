defmodule RedMutex do
  @moduledoc """
      defmodule MyMutex do
        use RedMutex, otp_app: :my_app
      end

      config :my_app, MyMutex,
        redis_url: "redis://redix.example.com:6380",
        key: "something"

      {:ok, mutex} = MyMutex.lock(12)

      true = MyMutex.locked?

      :ok = MyMutex.unlock(mutex)

      import MyMutex, only: [synchronize: 1]

      synchronize do
        // work
      end
  """

  @type mutex() :: String.t()
  @type reason() :: any()
  @type callback() :: fun() | {module :: atom(), function_name :: atom(), args :: [any()]}
  @callback lock :: {:ok, mutex()} | {:error, reason()}
  @callback exists_lock :: {:ok, boolean()} | {:error, reason()}
  @callback unlock(mutex()) :: :ok | {:error, reason()}
  @callback synchronize(callback()) :: any()

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour RedMutex
      @otp_app opts[:otp_app]

      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :supervisor
        }
      end

      def start_link(_opts) do
        url = RedMutex.Configuration.url(@otp_app, __MODULE__)
        RedMutex.Supervisor.start_link(mutex: __MODULE__, url: url)
      end

      @impl true
      def lock do
        key = RedMutex.Configuration.key(@otp_app, __MODULE__)
        expiration_in_seconds = RedMutex.Configuration.expiration_in_seconds(@otp_app, __MODULE__)
        RedMutex.Command.lock(__MODULE__, key, expiration_in_seconds)
      end

      @impl true
      def unlock(mutex) when is_binary(mutex) do
        key = RedMutex.Configuration.key(@otp_app, __MODULE__)
        RedMutex.Command.unlock(__MODULE__, key, mutex)
      end

      @impl true
      def exists_lock do
        key = RedMutex.Configuration.key(@otp_app, __MODULE__)
        RedMutex.Command.exists_lock(__MODULE__, key)
      end

      @impl true
      def synchronize(action) do
        case lock() do
          {:ok, mutex} ->
            try do
              run(action)
            rescue
              err ->
                {:error, err}
            after
              unlock(mutex)
            end

          err ->
            err
        end
      end

      defp run(action) when is_function(action) do
        action.()
      end

      defp run({module, function_name, args})
           when is_atom(module) and is_atom(function_name) and is_list(args) do
        apply(module, function_name, args)
      end
    end
  end
end
