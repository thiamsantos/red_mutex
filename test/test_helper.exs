Application.put_env(:red_mutex, RedMutexTest.MyMutex,
  url: "redis://localhost:6379",
  key: "key",
  expiration_in_seconds: 1_200
)

ExUnit.start()
