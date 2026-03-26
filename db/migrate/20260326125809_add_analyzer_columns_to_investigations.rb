class AddAnalyzerColumnsToInvestigations < ActiveRecord::Migration[8.1]
  def change
    add_column :investigations, :source_misrepresentation, :json
    add_column :investigations, :temporal_manipulation, :json
    add_column :investigations, :statistical_deception, :json
    add_column :investigations, :selective_quotation, :json
    add_column :investigations, :authority_laundering, :json
    add_column :investigations, :emotional_manipulation, :json
  end
end
