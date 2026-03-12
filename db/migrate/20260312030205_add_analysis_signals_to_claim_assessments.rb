class AddAnalysisSignalsToClaimAssessments < ActiveRecord::Migration[8.1]
  def change
    add_column :claim_assessments, :citation_depth_score, :decimal, precision: 5, scale: 2, default: 1.0, null: false
    add_column :claim_assessments, :primary_vetoed, :boolean, default: false, null: false
    add_column :claim_assessments, :unsubstantiated_viral, :boolean, default: false, null: false
  end
end
