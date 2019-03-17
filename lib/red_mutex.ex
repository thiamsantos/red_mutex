defmodule RedMutex do
  @moduledoc """
  Defines a mutex.

  A mutex defines an easy to use interface to interact with an
  [distributed lock backed by redis](https://redis.io/topics/distlock).

  When used, the mutex expects the :otp_app as option.
  The :otp_app should point to an OTP application that has the mutex configuration.
  For example, the mutex:

      defmodule MyApp.MyMutex do
        use RedMutex, otp_app: :my_app
      end

  Could be configured with:

      config :my_app, MyApp.MyMutex,
        url: "redis://localhost:6379",
        key: "red_mutex_lock",
        expiration_in_seconds: 3_600

  Options:

    * `:url` - the redis url. Required.
    * `:key`- The key at redis used to store the lock information.
      Defaults to `"red_mutex_lock"`.
    * `:expiration_in_seconds` - Time in seconds that the resource will be kept locked.
      After that time the lock will be automattically released.
      Defaults to `3600`, one hour.

  """

  @type lock() :: String.t()
  @type reason() :: any()
  @type callback() :: fun() | {module :: atom(), function_name :: atom(), args :: [any()]}

  @doc """
  Attempts to acquire an lock.

  ## Examples

      iex> MyMutex.acquire_lock()
      {:ok, lock}
      iex> MyMutex.acquire_lock()
      {:error, :already_locked}
      iex> MyMutex.acquire_lock()
      {:error, reason}

  """
  @callback acquire_lock :: {:ok, lock()} | {:error, :already_locked} | {:error, reason()}

  @doc """
  Checks if an lock exists. Returns `{:ok, true}` if the resource is locked.

  ## Examples

      iex> MyMutex.exists_lock()
      {:ok, true}
      iex> MyMutex.exists_lock()
      {:ok, false}
      iex> MyMutex.exists_lock()
      {:error, reason}

  """
  @callback exists_lock :: {:ok, boolean()} | {:error, reason()}

  @doc """
  Releases the lock.

  ## Examples

      iex> MyMutex.release_lock(lock)
      :ok
      iex> MyMutex.release_lock(lock)
      {:error, :unlock_fail}
      iex> MyMutex.release_lock(lock)
      {:error, reason}

  """
  @callback release_lock(lock()) :: :ok | {:error, reason()}

  @doc """
  Obtains an lock, run the callback, and releases the lock when the block completes.

  ## Examples

      iex> MyMutex.synchronize(fn ->
      ...>   # work
      ...>   {:ok, "completed"}
      ...> end)
      {:ok, "completed"}
      iex> MyMutex.synchronize({MyApp, :work, []})
      {:ok, "completed"}

  """
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
      def acquire_lock do
        key = RedMutex.Configuration.key(@otp_app, __MODULE__)
        expiration_in_seconds = RedMutex.Configuration.expiration_in_seconds(@otp_app, __MODULE__)
        RedMutex.Command.acquire_lock(__MODULE__, key, expiration_in_seconds)
      end

      @impl true
      def release_lock(lock) when is_binary(lock) do
        key = RedMutex.Configuration.key(@otp_app, __MODULE__)
        RedMutex.Command.release_lock(__MODULE__, key, lock)
      end

      @impl true
      def exists_lock do
        key = RedMutex.Configuration.key(@otp_app, __MODULE__)
        RedMutex.Command.exists_lock(__MODULE__, key)
      end

      @impl true
      def synchronize(action) do
        case acquire_lock() do
          {:ok, lock} ->
            try do
              run(action)
            rescue
              err ->
                {:error, err}
            after
              release_lock(lock)
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
