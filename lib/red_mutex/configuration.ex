defmodule RedMutex.Configuration do
  @moduledoc false

  def url(otp_app, mutex) do
    otp_app
    |> Application.fetch_env!(mutex)
    |> Keyword.fetch!(:url)
  end

  def key(otp_app, mutex) do
    otp_app
    |> Application.fetch_env!(mutex)
    |> Keyword.get(:key, "red_mutex_lock")
  end

  def expiration_in_seconds(otp_app, mutex) do
    otp_app
    |> Application.fetch_env!(mutex)
    |> Keyword.get(:expiration_in_seconds, 3_600)
  end
end
