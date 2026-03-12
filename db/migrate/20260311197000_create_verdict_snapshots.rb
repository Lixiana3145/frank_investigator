class CreateVerdictSnapshots < ActiveRecord::Migration[8.1]
  def change
    create_table :verdict_snapshots do |t|
      t.references :claim_assessment, null: false, foreign_key: true
      t.string :verdict, null: false
      t.string :previous_verdict
      t.decimal :confidence_score, precision: 5, scale: 2
      t.text :reason_summary
      t.string :trigger, null: false
      t.string :triggered_by
      t.datetime :created_at, null: false

      t.index [:claim_assessment_id, :created_at]
    end
  end
end
