defmodule RedMutexTest do
  use ExUnit.Case

  defmodule MyMutex do
    use RedMutex, otp_app: :red_mutex
  end

  defmodule Worker do
    def perform(arg) do
      {:ok, arg}
    end
  end

  setup do
    conn = start_supervised!({Redix, "redis://localhost:6379"})
    Redix.command!(conn, ["FLUSHALL"])
    Redix.command!(conn, ["SCRIPT", "FLUSH"])

    start_supervised!(MyMutex)

    wait_for_script_load(conn)

    %{conn: conn}
  end

  describe "start_link/1" do
    test "should update create an script", %{conn: conn} do
      assert [1] =
               Redix.command!(conn, [
                 "SCRIPT",
                 "EXISTS",
                 "5c252c1a0eaeeb4522fbbb982baba4e74ddfcd0d"
               ])
    end
  end

  describe "child_spec/1" do
    test "return correct child spec" do
      assert MyMutex.child_spec(name: :foo) == %{
               id: MyMutex,
               start: {MyMutex, :start_link, [[name: :foo]]},
               type: :supervisor
             }
    end
  end

  describe "acquire_lock/0" do
    test "locked once", %{conn: conn} do
      assert Redix.command!(conn, ["GET", "key"]) == nil
      assert {:ok, lock} = MyMutex.acquire_lock()
      assert Redix.command!(conn, ["GET", "key"]) == lock
      assert MyMutex.acquire_lock() == {:error, :already_locked}
    end

    test "returns an valid lock" do
      assert {:ok, lock} = MyMutex.acquire_lock()
      assert :ok = MyMutex.release_lock(lock)
    end
  end

  describe "release_lock/1" do
    test "unlock valid lock", %{conn: conn} do
      assert {:ok, lock} = MyMutex.acquire_lock()
      assert Redix.command!(conn, ["GET", "key"]) == lock
      assert :ok = MyMutex.release_lock(lock)
      assert Redix.command!(conn, ["GET", "key"]) == nil
    end

    test "invalid lock" do
      assert {:error, :unlock_fail} = MyMutex.release_lock("invalid_lock")
    end

    test "already unlocked" do
      assert {:ok, lock} = MyMutex.acquire_lock()
      assert :ok = MyMutex.release_lock(lock)
      assert {:error, :unlock_fail} = MyMutex.release_lock(lock)
    end
  end

  describe "exists_lock/0" do
    test "return true when mutex is locked" do
      assert {:ok, _lock} = MyMutex.acquire_lock()

      assert MyMutex.exists_lock() == {:ok, true}
    end

    test "return false when mutex is unlocked" do
      assert {:ok, lock} = MyMutex.acquire_lock()
      assert :ok = MyMutex.release_lock(lock)

      assert MyMutex.exists_lock() == {:ok, false}
    end
  end

  describe "synchronize/1" do
    test "accepts function", %{conn: conn} do
      assert Redix.command!(conn, ["GET", "key"]) == nil

      actual =
        MyMutex.synchronize(fn ->
          assert Redix.command!(conn, ["GET", "key"]) != nil
          {:ok, "something"}
        end)

      assert Redix.command!(conn, ["GET", "key"]) == nil

      assert actual == {:ok, "something"}
    end

    test "accepts mod/fun/args" do
      actual = MyMutex.synchronize({RedMutexTest.Worker, :perform, ["arg"]})
      expected = {:ok, "arg"}

      assert actual == expected
    end

    test "capture errors", %{conn: conn} do
      assert Redix.command!(conn, ["GET", "key"]) == nil

      actual =
        MyMutex.synchronize(fn ->
          assert Redix.command!(conn, ["GET", "key"]) != nil
          raise RuntimeError, "err"
        end)

      assert Redix.command!(conn, ["GET", "key"]) == nil

      assert {:error, %RuntimeError{message: "err"}} = actual
    end
  end

  defp wait_for_script_load(conn) do
    [response] =
      Redix.command!(conn, [
        "SCRIPT",
        "EXISTS",
        "5c252c1a0eaeeb4522fbbb982baba4e74ddfcd0d"
      ])

    if response == 1 do
      conn
    else
      wait_for_script_load(conn)
    end
  end
end
