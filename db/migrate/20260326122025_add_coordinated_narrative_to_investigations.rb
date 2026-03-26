class AddCoordinatedNarrativeToInvestigations < ActiveRecord::Migration[8.1]
  def change
    add_column :investigations, :coordinated_narrative, :json
  end
end
