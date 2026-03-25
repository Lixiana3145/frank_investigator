class AddContextualGapsToInvestigations < ActiveRecord::Migration[8.1]
  def change
    add_column :investigations, :contextual_gaps, :json
  end
end
