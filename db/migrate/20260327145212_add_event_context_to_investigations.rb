class AddEventContextToInvestigations < ActiveRecord::Migration[8.1]
  def change
    add_column :investigations, :event_context, :json
  end
end
