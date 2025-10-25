class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.text :content
      t.string :sender, default: 'anonymous'
      t.references :post, null: false, foreign_key: true

      t.timestamps
    end
  end
end
