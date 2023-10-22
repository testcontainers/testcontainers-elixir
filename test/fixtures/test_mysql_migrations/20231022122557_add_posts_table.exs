defmodule Testcontainers.Test.Mysql.Migrations.AddPostsTable do
  use Ecto.Migration

  def change do
    create table(:users) do
      add(:email, :string, null: false)
      add(:hashed_password, :string, null: false)
      add(:confirmed_at, :naive_datetime)
      timestamps()
    end
  end
end
