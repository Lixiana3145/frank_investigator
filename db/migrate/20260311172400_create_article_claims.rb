class CreateArticleClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :article_claims do |t|
      t.references :article, null: false, foreign_key: true
      t.references :claim, null: false, foreign_key: true
      t.string :role, null: false, default: "body"
      t.text :surface_text, null: false
      t.string :stance, null: false, default: "repeats"
      t.decimal :importance_score, precision: 5, scale: 2, null: false, default: 0
      t.boolean :title_related, null: false, default: false

      t.timestamps
    end

    add_index :article_claims, [ :article_id, :claim_id, :role ], unique: true
  end
end
