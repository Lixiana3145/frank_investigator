class CreateClaims < ActiveRecord::Migration[8.1]
  def change
    create_table :claims do |t|
      t.text :canonical_text, null: false
      t.string :canonical_fingerprint, null: false
      t.string :claim_kind, null: false, default: "statement"
      t.string :checkability_status, null: false, default: "pending"
      t.string :topic
      t.json :entities_json, null: false, default: {}
      t.string :time_scope
      t.datetime :first_seen_at
      t.datetime :last_seen_at

      t.timestamps
    end

    add_index :claims, :canonical_fingerprint, unique: true
    add_index :claims, :checkability_status
  end
end
