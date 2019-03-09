defmodule RedMutex do
  @moduledoc """
  Documentation for RedMutex.
  """

  @doc """
  Hello world.

  ## Examples

      iex> RedMutex.hello()
      :world

  """
  # def hello do
  #   :crypto.hash(:sha256, :crypto.strong_rand_bytes(32))
  #   |> Base.encode64()
  #   |> IO.inspect()

  #   :world
  # end

  # @doc """
  # defmodule MyMutex do
  #   use RedMutex, otp_app: :my_app
  # end

  # config :my_app, MyMutex,
  #   redis_url: "redis://redix.example.com:6380",
  #   key: "something"

  # {:ok, mutex} = MyMutex.lock(12)

  # true = MyMutex.locked?

  # :ok = MyMutex.unlock(mutex)

  # import MyMutex, only: [synchronize: 1]

  # synchronize do
  #   // work
  # end
  # """

  @type mutex() :: String.t()
  @type reason() :: any()
  @callback lock(expiration_in_seconds :: integer()) :: {:ok, mutex()} | {:error, reason()}
  @callback exists_lock :: {:ok, boolean()} | {:error, reason()}
  @callback unlock(mutex()) :: :ok | {:error, reason()}

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

      def start_link(opts \\ []) do
        RedMutex.Supervisor.start_link(__MODULE__, @otp_app, opts)
      end

      @impl true
      def lock do
        RedMutex.Command.lock(__MODULE__, "key", 1200)
      end

      @impl true
      def unlock(mutex) do
        RedMutex.Command.unlock(__MODULE__, "key", mutex)
      end

      @impl true
      def exists_lock do
        RedMutex.Command.exists_lock(__MODULE__, "key")
      end
    end
  end
end
