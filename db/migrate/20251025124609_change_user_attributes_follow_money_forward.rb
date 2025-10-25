class ChangeUserAttributesFollowMoneyForward < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :nickname, :string
    add_column :users, :comment, :string
    add_column :users, :user_id, :string

    execute "UPDATE users SET user_id = id"

    change_column_null :users, :user_id, false

    remove_column :posts, :user_id
    add_column :posts, :user_id, :string
  
    remove_foreign_key :posts, :users if foreign_key_exists?(:posts, :users)

    execute "ALTER TABLE users DROP CONSTRAINT users_pkey;"
    execute "ALTER TABLE users ADD PRIMARY KEY (user_id)"

    add_foreign_key :posts, :users, column: :user_id, primary_key: :user_id
    remove_column :users, :id
  end
end
