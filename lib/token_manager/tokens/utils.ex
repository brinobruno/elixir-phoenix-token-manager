defmodule TokenManager.Tokens.Utils do
  @number_of_tokens 3
  @max_concurrency 8
  @max_active_token_duration_in_minutes 1
  @check_interval_in_seconds 5

  def get(:number_of_tokens) do
    @number_of_tokens
  end

  def get(:max_concurrency) do
    @max_concurrency
  end

  def get(:max_active_token_duration_in_minutes) do
    @max_active_token_duration_in_minutes
  end

  def get(:check_interval_in_seconds) do
    @check_interval_in_seconds
  end
end
