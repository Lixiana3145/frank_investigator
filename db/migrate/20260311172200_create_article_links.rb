class CreateArticleLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :article_links do |t|
      t.references :source_article, null: false, foreign_key: { to_table: :articles }
      t.references :target_article, null: false, foreign_key: { to_table: :articles }
      t.string :href, null: false
      t.string :anchor_text
      t.text :context_excerpt
      t.integer :position, null: false, default: 0
      t.string :follow_status, null: false, default: "pending"
      t.integer :depth, null: false, default: 0

      t.timestamps
    end

    add_index :article_links, [ :source_article_id, :href ], unique: true
    add_index :article_links, :follow_status
  end
end
