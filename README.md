# RedMutex

[![Hex.pm Version](http://img.shields.io/hexpm/v/red_mutex.svg?style=flat)](https://hex.pm/packages/red_mutex)
[![CI](https://github.com/thiamsantos/red_mutex/workflows/CI/badge.svg?branch=master)](https://github.com/thiamsantos/red_mutex/actions)
[![Coverage Status](https://coveralls.io/repos/github/thiamsantos/red_mutex/badge.svg?branch=master)](https://coveralls.io/github/thiamsantos/red_mutex?branch=master)

RedMutex defines an easy to use interface to control an [distributed lock backed by redis](https://redis.io/topics/distlock).

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

## Usage

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

## Contributing

See the [contributing file](CONTRIBUTING.md).

## License

[Apache License, Version 2.0](LICENSE) © [Thiago Santos](https://github.com/thiamsantos)
