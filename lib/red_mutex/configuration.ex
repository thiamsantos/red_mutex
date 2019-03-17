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
    |> Keyword.fetch!(:key)
  end

  def expiration_in_seconds(otp_app, mutex) do
    otp_app
    |> Application.fetch_env!(mutex)
    |> Keyword.fetch!(:expiration_in_seconds)
  end
end
