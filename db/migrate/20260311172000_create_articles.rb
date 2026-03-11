class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles do |t|
      t.string :url, null: false
      t.string :normalized_url, null: false
      t.string :host, null: false
      t.string :title
      t.datetime :published_at
      t.text :body_text
      t.text :excerpt
      t.string :fetch_status, null: false, default: "pending"
      t.string :content_fingerprint
      t.datetime :fetched_at
      t.string :main_content_path

      t.timestamps
    end

    add_index :articles, :normalized_url, unique: true
    add_index :articles, :host
    add_index :articles, :fetch_status
  end
end
