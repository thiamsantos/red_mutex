# RedMutex

<!-- MDOC !-->

[![Hex.pm Version](http://img.shields.io/hexpm/v/red_mutex.svg?style=flat)](https://hex.pm/packages/red_mutex)
[![CI](https://github.com/thiamsantos/red_mutex/workflows/CI/badge.svg?branch=master)](https://github.com/thiamsantos/red_mutex/actions)
[![Coverage Status](https://coveralls.io/repos/github/thiamsantos/red_mutex/badge.svg?branch=master)](https://coveralls.io/github/thiamsantos/red_mutex?branch=master)

RedMutex defines an easy to use interface to control an [distributed lock backed by redis](https://redis.io/topics/distlock).

## Usage

When used, the mutex expects the :otp_app as option.
The :otp_app should point to an OTP application that has the mutex configuration.
For example, the mutex:

```elixir
defmodule MyApp.MyMutex do
  use RedMutex, otp_app: :my_app
end
```

Could be configured with:

```elixir
config :my_app, MyApp.MyMutex,
  url: "redis://localhost:6379",
  key: "red_mutex_lock",
  expiration_in_seconds: 3_600
```

Options:

  * `:url` - the redis url. Required.
  * `:key`- The key at redis used to store the lock information.
    Defaults to `"red_mutex_lock"`.
  * `:expiration_in_seconds` - Time in seconds that the resource will be kept locked.
    After that time the lock will be automattically released.
    Defaults to `3600`, one hour.

### Example

```elixir
# In your config/config.exs file
config :my_app, MyApp.MyMutex,
  url: "redis://localhost:6379",
  key: "red_mutex_lock",
  expiration_in_seconds: 3_600

# In your application code
defmodule MyApp.MyMutex do
  use RedMutex, otp_app: :my_app
end

defmodule MyApp do
  import RedMutex, only: [synchronize: 1]
  alias MyApp.MyMutex

  def syncronized_work do
    synchronize({__MODULE__, :work, []})
  end

  def lock_unlock do
    case MyMutex.acquire_lock() do
      {:ok, lock} ->
        work()
        MyMutex.release_lock(lock)

      {:error, reason} -> {:error, reason}
    end
  end

  def work do
    # do some work
    {:ok, "completed"}
  end
end
```

<!-- MDOC !-->

## Installation

The package can be installed
by adding `red_mutex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:red_mutex, "~> 0.2.2"}
  ]
end
```

The docs can be found at [https://hexdocs.pm/red_mutex](https://hexdocs.pm/red_mutex).

## Contributing

See the [contributing file](CONTRIBUTING.md).

## License

[Apache License, Version 2.0](LICENSE) © [Thiago Santos](https://github.com/thiamsantos)
