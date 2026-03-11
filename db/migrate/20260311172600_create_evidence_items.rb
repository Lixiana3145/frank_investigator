class CreateEvidenceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :evidence_items do |t|
      t.references :claim_assessment, null: false, foreign_key: true
      t.references :article, null: true, foreign_key: true
      t.string :source_url, null: false
      t.string :source_type, null: false, default: "article"
      t.datetime :published_at
      t.string :stance, null: false, default: "unknown"
      t.text :excerpt
      t.string :citation_locator
      t.decimal :authority_score, precision: 5, scale: 2, null: false, default: 0
      t.string :independence_group

      t.timestamps
    end

    add_index :evidence_items, :source_type
  end
end
