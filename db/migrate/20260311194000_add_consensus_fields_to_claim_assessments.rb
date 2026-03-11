class AddConsensusFieldsToClaimAssessments < ActiveRecord::Migration[8.1]
  def change
    add_column :claim_assessments, :disagreement_details, :text
    add_column :claim_assessments, :unanimous, :boolean, default: false, null: false
  end
end
