class CreateClaimAssessments < ActiveRecord::Migration[8.1]
  def change
    create_table :claim_assessments do |t|
      t.references :investigation, null: false, foreign_key: true
      t.references :claim, null: false, foreign_key: true
      t.string :verdict, null: false, default: "pending"
      t.decimal :confidence_score, precision: 5, scale: 2, null: false, default: 0
      t.string :checkability_status, null: false, default: "pending"
      t.text :reason_summary
      t.text :missing_evidence_summary
      t.decimal :conflict_score, precision: 5, scale: 2, null: false, default: 0
      t.decimal :authority_score, precision: 5, scale: 2, null: false, default: 0
      t.decimal :independence_score, precision: 5, scale: 2, null: false, default: 0
      t.decimal :timeliness_score, precision: 5, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :claim_assessments, [ :investigation_id, :claim_id ], unique: true
    add_index :claim_assessments, :verdict
    add_index :claim_assessments, :checkability_status
  end
end
