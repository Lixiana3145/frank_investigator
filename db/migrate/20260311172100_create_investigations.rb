class CreateInvestigations < ActiveRecord::Migration[8.1]
  def change
    create_table :investigations do |t|
      t.string :submitted_url, null: false
      t.string :normalized_url, null: false
      t.string :status, null: false, default: "queued"
      t.references :root_article, null: true, foreign_key: { to_table: :articles }
      t.decimal :headline_bait_score, precision: 5, scale: 2, null: false, default: 0
      t.decimal :overall_confidence_score, precision: 5, scale: 2, null: false, default: 0
      t.string :checkability_status, null: false, default: "pending"
      t.text :summary
      t.datetime :analysis_completed_at

      t.timestamps
    end

    add_index :investigations, :normalized_url, unique: true
    add_index :investigations, :status
    add_index :investigations, :checkability_status
  end
end
